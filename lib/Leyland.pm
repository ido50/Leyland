package Leyland;

use Moose;
use namespace::autoclean;
use Leyland::Context;
use JSON::Any;
use File::Util;
use Log::Handler;
use Carp;
use Data::Dumper;
use Module::Load;
use Tie::IxHash;

has 'config' => (is => 'ro', isa => 'HashRef', builder => '_init_config');

has 'log' => (is => 'ro', isa => 'Log::Handler', builder => '_init_log');

has 'views' => (is => 'ro', isa => 'ArrayRef', predicate => 'has_views', writer => '_set_views');

has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

has 'futil' => (is => 'ro', isa => 'File::Util', default => sub { File::Util->new });

has 'json' => (is => 'ro', isa => 'Object', default => sub { JSON::Any->new }); # 'isa' should be 'JSON::Any', but for some reason JSON::Any->new blesses an array-ref, so validation fails

sub _init_log {
	my $log = Log::Handler->new();
	$log->add(file => { filename => 'output.log', minlevel => 'notice', maxlevel => 'debug' });
	$log->add(screen => { log_to => 'STDOUT', minlevel => 'notice', maxlevel => 'debug' });
	return $log;
}

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

	# init views, if any, start with view modules in the app
	my @views = $self->_views || ();
	# now load views defined in the config file
	VIEW: foreach (@{$self->config->{views}}) {
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
	my %params = ( env => $env, log => $self->log, config => $self->config );
	$params{views} = $self->views if $self->has_views;
	my $c = Leyland::Context->new(%params);

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

	# print some useful debug messages
	$c->log->info('['.uc($c->req->method).']', $c->req->address, $c->req->path);

	# find matching routes
	$self->find_routes($c);

	$c->log->notice("Finished looking for routes");
	
	# have we found any routes
	if ($c->has_routes) {
		$c->res->content_type('text/html');

		my $i = 0;
		my $ret = $c->routes->[$i]->{code}->($c);
		while ($c->pass_next && $i < 100) { # $i is also used to prevent infinite loops
			# we need to pass to the next matching route
			# first, let's erase the pass flag from the context
			# so we don't try to do this infinitely
			$c->_pass(0);
			
			# invoke the subroutine of the new route
			$ret = $c->routes->[++$i]->{code}->($c);
		}
		
		# what kind of response did I get?
		if (ref $ret) {
			# we need to deserialize this
			$ret = $self->json->to_json($ret);
		}
		
		$c->res->body($ret);

		return $c->res->finalize;
	} else {
		return $self->not_found($c);
	}
}

sub find_routes {
	my ($self, $c) = @_;

	$c->log->notice("Starting to look for routes");

	my $path = $c->req->path;
	# add a trailing slash to the path unless there is one
	#$path .= '/' unless $path =~ m!/$!;

	# let's find all possible prefix/route combinations
	# from the path
	my @pref_routes = ({ prefix => '', route => $path });
	my ($prefix) = ($path =~ m!^(/[^/]+)!);
	my $route = $' || '/';
	my $i = 0; # counter to prevent infinite loops, probably should removed
	while ($prefix && $i < 100) {
		$c->log->notice("Adding prefix $prefix, route $route");
		push(@pref_routes, { prefix => $prefix, route => $route });
		
		my ($suffix) = ($route =~ m!^(/[^/]+)!);
		last unless $suffix;
		$prefix .= $suffix;
		$route = $' || '/';
		$i++;
	}

	my $routes;
	foreach (@pref_routes) {		
		my $pref_name = $_->{prefix} || '_root_';

		next unless $self->routes->EXISTS($pref_name);

		$c->log->notice("Looking for routes in $pref_name");

		my $pref_routes = $self->routes->FETCH($pref_name);
		
		# find matching routes in this prefix
		foreach my $r ($pref_routes->Keys) {
			# does the requested route match the current route?
			next unless $_->{route} =~ m/$r/;

			my $route_meths = $pref_routes->FETCH($r);

			# find all routes that support the request method (i.e. GET, POST, etc.)
			foreach my $ms (sort { $a =~ m/\|/ <=> $b =~ m/\|/ || $a eq 'any' || $b eq 'any' } keys %$route_meths) {
				# it does, but is there a subroutine for the exact request method?
				foreach my $m (split(/\|/, $ms)) {
					next unless $m eq lc($c->req->method) || $m eq 'any';

					push(@$routes, { prefix => $_->{prefix}, route => $r, code => $route_meths->{$m} });
				}
			}
		}
	}

	# save matching routes in the context object
	$c->_set_routes($routes) if defined $routes && scalar @$routes;
}

sub not_found {
	my ($self, $c) = @_;

	$c->res->content_type('text/html');
	$c->res->body('404 Not Found');

	return $c->res->finalize;
}

sub _default_config {
	{
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
