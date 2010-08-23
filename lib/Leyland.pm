package Leyland;

use Moose;
use namespace::autoclean;
use Leyland::Context;
use Leyland::Negotiator;
use JSON::Any;
use XML::TreePP;
use File::Util;
use Carp;
use Data::Dumper;
use Module::Load;
use Tie::IxHash;

has 'config' => (is => 'ro', isa => 'HashRef', builder => '_init_config');

has 'logger' => (is => 'ro', does => 'Leyland::Logger', writer => '_set_logger');

has 'localizer' => (is => 'ro', does => 'Leyland::Localizer', writer => '_set_localizer');

has 'views' => (is => 'ro', isa => 'ArrayRef', predicate => 'has_views', writer => '_set_views');

has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

has 'futil' => (is => 'ro', isa => 'File::Util', default => sub { File::Util->new });

has 'json' => (is => 'ro', isa => 'Object', default => sub { JSON::Any->new }); # 'isa' should be 'JSON::Any', but for some reason JSON::Any->new blesses an array-ref, so validation fails

has 'xml' => (is => 'ro', isa => 'XML::TreePP', default => sub { my $xml = XML::TreePP->new(); $xml->set(utf8_flag => 1); return $xml; });

has 'conneg' => (is => 'ro', isa => 'Leyland::Negotiator', default => sub { Leyland::Negotiator->new });

sub _init_config {
	my $self = shift;

	my $config;

	if (-e 'config.json' && $self->futil->can_read('config.json')) {
		# we have a config file, let's load it
		my $json = $self->futil->load_file('config.json');
		$config = $self->json->from_json($json);
	} else {
		if (-e 'config.json') {
			# we couldn't read the config file (permission problem?)
			carp "Leyland can't read the config.json file, please check the file's permissions.";
		}
			
		# let's create a default config
		$config = $self->_default_config;
	}

	return $config;
}
	
sub BUILD {
	my $self = shift;
	
	my $config = $self->config;

	# init logger, and if none are set, use Log::Handler
	if (exists $config->{logger} && exists $config->{logger}->{class}) {
		my $class = 'Leyland::Logger::'.$config->{logger}->{class};
		load $class;
		my $logger = $class->init($config);
		$self->_set_logger($logger);
	} else {
		load Leyland::Logger::LogHandler;
		my $logger = Leyland::Logger::LogHandler->init();
		$self->_set_logger($logger);
	}

	# init localizer, if any
	if (exists $config->{localizer} && exists $config->{localizer}->{class}) {
		my $class = 'Leyland::Localizer::'.$config->{localizer}->{class}
			unless $config->{localizer}->{class} =~ s/^\+//;
		load $class;
		my $localizer = $class->init($config);
		$self->_set_localizer($localizer);
	}

	# init views, if any, start with view modules in the app
	my @views = $self->_views || ();
	# now load views defined in the config file
	VIEW: foreach (@{$config->{views}}) {
		$self->log->info("Looking at view $_");

		# have we already loaded this view in the first step?
		foreach my $v ($self->_views) {
			next VIEW if $v eq $_;
		}

		# attempt to load this view
		my $class = "Leyland::View::$_";
		load $class;
		push(@views, $class->new());
	}
	$self->_set_views(\@views) if scalar @views;

	# get all routes
	my $routes = Tie::IxHash->new;
	foreach ($self->controllers) {
		my $prefix = $_->prefix || '_root_';
		$routes->Push($prefix => $_->routes);
	}
	$self->_set_routes($routes);
}

sub handle {
	my ($self, $env) = @_;

	# create the context object
	my %params = ( shutton => $self, env => $env, config => $self->config );
	$params{views} = $self->views if $self->has_views;
	my $c = Leyland::Context->new(%params);

	# give the context object a logger
	$c->_set_log($self->logger->new_request_log($c->req));

	# does the request path have an "unnecessary" trailing slash?
	# if so, remove it and redirect to the new path
	if ($c->req->path ne '/' && $c->req->path =~ m!/$!) {
		my $newpath = $`;
		$c->res->content_type('text/html');
		my $uri = $c->req->uri;
		$uri->path($newpath);
		
		$c->res->redirect($uri, 301);
		return $c->res->finalize;
	}

	# Leyland only supports UTF-8 character encodings, so let's check
	# the client supports that. If not, let's return an error
	$self->conneg->negotiate_charset($c);

	# find matching routes (will issue an error if none found or none
	# return client's acceptable media types)
	my @routes = $self->conneg->find_routes($c, $self->routes);

	$c->_set_routes(\@routes);
	
	# invoke the first matching route
	my $i = 0;
	$c->_set_controller($c->routes->[$i]->{route}->{class});
	my $ret = $self->deserialize($c, $c->routes->[$i]->{route}->{code}->($c->routes->[$i]->{route}->{class}, $c, @{$c->routes->[$i]->{route}->{captures}}), $c->routes->[$i]->{media});

	while ($c->pass_next && $i < scalar @{$c->routes} && $i < 100) { # $i is also used to prevent infinite loops
		# we need to pass to the next matching route
		# first, let's erase the pass flag from the context
		# so we don't try to do this infinitely
		$c->_pass(0);
		
		# invoke the subroutine of the new route
		$c->_set_controller($c->routes->[$i]->{route}->{class});
		$ret = $self->deserialize($c, $c->routes->[++$i]->{route}->{code}->($c->routes->[$i]->{route}->{class}, $c, @{$c->routes->[$i]->{route}->{captures}}), $c->routes->[$i]->{media});
	}

	$c->res->body($ret);

	return $c->res->finalize;
}

sub log {
	$_[0]->logger->logger;
}

sub deserialize {
	my ($self, $c, $obj, $want) = @_;

	my $ct = $want.';charset=UTF-8' if $want =~ m/text|json|xml|html|atom/;
	$c->res->content_type($ct);

	if (ref $obj eq 'ARRAY' && scalar @$obj == 2) {
		# render specified template
		return $c->template($obj->[0]->{$want}, $obj->[1]);
	} elsif (ref $obj eq 'ARRAY' || ref $obj eq 'HASH') {
		# deserialize according to wanted type
		if ($want eq 'application/json') {
			return $self->json->to_json($obj);
		} elsif ($want eq 'application/atom+xml' || $want eq 'application/xml') {
			return $self->xml->write($obj);
		} else {
			# just use Data::Dumper
			return Dumper($obj);
		}			
	} else { # implied(?): ref $obj eq 'SCALAR'
		# return as is
		return $obj;
	}
}

sub _default_config {
	{
		app => 'ReqRes',
		env => 'development',
		environments => {
			development => {
				minlevel => 'notice',
				maxlevel => 'debug',
			},
			production => {
				minlevel => 'warning',
				maxlevel => 'debug',
			}
		},
		logger => {
			class => 'LogShutton',
		},
		localizer => {
			class => 'Wolowitz',
			db_name => 'wolowitz',
		},
		views => ['Tenjin'],
	}
}

=head1 NAME

Leyland - The great new Leyland!

=head1 SYNOPSIS

	use Leyland;

	my $foo = Leyland->new();
	...

=head1 METHODS

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Leyland>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Leyland>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Leyland>

=item * Search CPAN

L<http://search.cpan.org/dist/Leyland/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

__PACKAGE__->meta->make_immutable;
