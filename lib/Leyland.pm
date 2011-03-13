package Leyland;

# ABSTRACT: A Plack-based application framework that makes no sense

$Leyland::VERSION = 0.1;

use Moose;
use namespace::autoclean;

use Carp;
use Data::Dumper;
use Encode;
use Leyland::Localizer;
use Leyland::Negotiator;
use Module::Load;
use Text::SpanningTable;
use Tie::IxHash;
use Try::Tiny;

=head1 NAME

Leyland - A Plack-based application framework that makes no sense

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 CLASS METHODS

=head1 OBJECT METHODS

=cut

has 'config' => (is => 'ro', isa => 'HashRef', default => sub { __PACKAGE__->_default_config });

has 'log' => (is => 'ro', does => 'Leyland::Logger', writer => '_set_log');

has 'localizer' => (is => 'ro', isa => 'Leyland::Localizer', predicate => 'has_localizer', writer => '_set_localizer');

has 'views' => (is => 'ro', isa => 'ArrayRef', predicate => 'has_views', writer => '_set_views');

has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

has 'req_counter' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_req_counter');

has 'context_class' => (is => 'ro', isa => 'Str', default => 'Leyland::Context');

has 'cwe' => (is => 'ro', isa => 'Str', default => $ENV{PLACK_ENV});

sub setup { 1 } # meant to be overridden

sub handle {
	my ($self, $env) = @_;

	# increment the request counter
	$self->_set_req_counter($self->req_counter + 1);

	# create the context object
	my $c = $self->context_class->new(
		app => $self,
		env => $env,
		num => $self->req_counter
	);

	# does the request path have an "unnecessary" trailing slash?
	# if so, remove it and redirect to the resulting URI
	if ($c->path ne '/' && $c->path =~ m!/$!) {
		my $newpath = $`;
		my $uri = $c->uri;
		$uri->path($newpath);
		
		$c->res->redirect($uri, 301);
		return $c->_respond;
	}

	# is this an OPTIONS request?
	if ($c->method eq 'OPTIONS') {
		# get all available methods by using Leyland::Negotiator
		# and return a 204 No Content response
		$c->log->info('Finding supported methods for requested path.');
		return $c->_respond(204, { 'Allow' => join(', ', Leyland::Negotiator->find_options($c, $self->routes)) });
	} else {
		# negotiate for routes and invoke the first matching route (if any).
		# handle route passes and return the final output after UTF-8 encoding.
		# if at any point an expception is raised, handle it.
		return try {
			# get routes
			$c->log->info('Searching matching routes.');
			$c->_set_routes(Leyland::Negotiator->negotiate($c, $self->routes));

			# invoke first route
			$c->log->info('Invoking first matching route.');
			my $ret = $c->_invoke_route;

			# are we passing to the next matching route?
			# to prevent infinite loops, limit passing to no more than 100 times
			while ($c->_pass_next && $c->current_route < 100) {
				# we need to pass to the next matching route.
				# first, let's erase the pass flag from the context
				# so we don't try to do this infinitely
				$c->_pass(0);
				# no let's invoke the route
				$ret = $c->_invoke_route;
			}

			$c->finalize(\$ret);
			
			$c->_respond(undef, undef, $ret);
		} catch {
			$self->_handle_exception($c, $_);
		};
	}
}

=head1 INTERNAL METHODS

The following methods are only to be used internally.

=cut

around BUILDARGS => sub {
	my ($orig, $class, %opts) = @_;

	# parse the config variable, take out environment-specific parameters
	if ($opts{config}) {
		my $envs = delete $opts{config}->{environments};
		if ($envs->{$ENV{PLACK_ENV}}) {
			foreach (keys %{$envs->{$ENV{PLACK_ENV}}}) {
				$opts{config}->{$_} = delete $envs->{$ENV{PLACK_ENV}}->{$_};
			}
		}
		delete $opts{config}->{environments};
		$opts{config}->{app} ||= 'MyApp';
	}

	# create the object
	return $class->$orig(%opts);
};

sub BUILD {
	my $self = shift;

	# load the context class
	load $self->context_class;

	# init logger
	if (exists $self->config->{logger}) {
		# load this logger
		if (ref $self->config->{logger} eq 'HASH') {
			my $class = $self->config->{logger}->{class}
				|| croak "You must provide the name of the logger class to use.";
			$class = 'Leyland::Logger::'.$class;

			# load the logger class
			load $class;
			my $log = $class->new;
			
			# initialize the class
			$log->init($self->config->{logger}->{opts});
			$self->_set_log($log);
		} else {
			my $class = 'Leyland::Logger::'.$self->config->{logger};
			load $class;
			$self->_set_log($class->new);
		}
	} else {
		# load the base logger
		load Leyland::Logger::STDERR;
		$self->_set_log(Leyland::Logger::STDERR->new);
	}

	# init localizer, if localization path given
	if (exists $self->config->{locales}) {
		$self->_set_localizer(Leyland::Localizer->new(path => $self->config->{locales}));
	}

	# require Module::Pluggable and load all views and controllers
	# with it
	load Module::Pluggable;
	Module::Pluggable->import(search_path => [$self->config->{app}.'::View'], sub_name => '_views', require => 1);
	Module::Pluggable->import(search_path => [$self->config->{app}.'::Controller'], sub_name => 'controllers', require => 1);

	# init views, if any, start with view modules in the app
	my @views = $self->_views || ();
	# now load views defined in the config file
	VIEW: foreach (@{$self->config->{views}}) {
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
		
		# in order to allow multiple controllers having the same
		# prefix, let's see if we've already encountered this prefix,
		# and if so, merge the routes
		if ($routes->EXISTS($prefix)) {
			foreach my $r ($_->routes->Keys) {
				foreach my $m (keys %{$_->routes->FETCH($r)}) {
					if ($routes->FETCH($prefix)->EXISTS($r)) {
						$routes->FETCH($prefix)->FETCH($r)->{$m} = $_->routes->FETCH($r)->{$m};
					} else {
						$routes->FETCH($prefix)->Push($r => { $m => $_->routes->FETCH($r)->{$m} });
					}
				}
			}
		} else {
			$routes->Push($prefix => $_->routes);
		}
	}
	$self->_set_routes($routes);

	# invoke setup method
	$self->setup();

	# print debug information
	$self->_initial_debug_info;
}

sub _handle_exception {
	my ($self, $c, $exp) = @_;

	# have we caught a Leyland::Exception object? if not, turn it into
	# a Leyland::Exception
	$exp = Leyland::Exception->new(code => 500, error => ref $exp ? Dumper($exp) : $exp)
		unless blessed $exp && $exp->isa('Leyland::Exception');

	# log the error thrown
	my $err = $exp->error || $Leyland::CODES->{$exp->code}->[0];
	$c->log->debug('Exception thrown: '.$exp->code.", message: $err");

	# is this a redirecting exception?
	if ($exp->code =~ m/^3\d\d$/ && $exp->has_location) {
		$c->res->redirect($exp->location);
		return $c->_respond($exp->code);
	}

	# do we have templates for any of the client's requested MIME types?
	# if so, render the first one you find.
	if ($exp->has_mimes) {
		foreach (@{$c->wanted_mimes}) {
			return $c->_respond(
				$exp->code,
				{ 'Content-Type' => $_->{mime}.'; charset=UTF-8' },
				$c->template($exp->mime($_->{mime}), $exp->hash, $exp->use_layout)
			) if $exp->has_mime($_->{mime});
		}
	}

	# we haven't found any templates for the request mime types, let's
	# attempt to serialize the error ourselves if the client accepts
	# JSON or XML
	foreach (@{$c->wanted_mimes}) {
		return $c->_respond(
			$exp->code,
			{ 'Content-Type' => $_->{mime}.'; charset=UTF-8' },
			$c->_serialize($exp->hash, $_->{mime})
		) if $_->{mime} eq 'application/json' || $_->{mime} eq 'application/atom+xml' || $_->{mime} eq 'application/xml';
	}

	# We do not support none of the MIME types the client wants,
	# let's return plain text
	return $c->_respond(
		$exp->code,
		{ 'Content-Type' => 'text/plain; charset=UTF-8' },
		Dumper($exp->error)
	);
}

sub _default_config { { app => 'Leyland', views => ['Tenjin'] } }

sub _autolog {
	my ($log, $string) = @_;

	$log->info($string);
}

sub _initial_debug_info {
	my $self = shift;

	my @views;
	foreach (sort @{$self->views}) {
		my $view = ref $_;
		$view =~ s/^Leyland::View:://;
		push(@views, $view);
	}

	my $t1 = Text::SpanningTable->new(96);
	$t1->exec(\&_autolog, $self->log);

	$t1->hr('top');
	$t1->row($self->config->{app}.' (powered by Leyland v'.$Leyland::VERSION.')');
	$t1->dhr;
	$t1->row('Current working environment: '.$self->cwe);
	$t1->row('Avilable views: '.join(', ', @views));
	$t1->row('Logger: '.ref($self->log));
	
	$t1->hr('bottom');
	
	$self->log->info('Available routes:');

	if ($self->has_routes) {
		my $t2 = Text::SpanningTable->new(16, 24, 13, 18, 18, 12);
		$t2->exec(\&_autolog, $self->log);
		
		$t2->hr('top');
		$t2->row('Prefix', 'Regex', 'Method', 'Accepts', 'Returns', 'Is');
		$t2->dhr;

		foreach (sort { ($b eq '_root_') <=> ($a eq '_root_') || $a cmp $b } $self->routes->Keys) {
			my $c = $_;
			$c =~ s!_root_!(root)!;
			my $pre = $self->routes->FETCH($_);
			foreach my $r (sort $pre->Keys) {
				my ($regex) = ($r =~ m/^\(\?-xism:(.+)\)$/);
				my $reg = $pre->FETCH($r);
				foreach my $m (sort keys %$reg) {
					my $returns = ref $reg->{$m}->{rules}->{returns} eq 'ARRAY' ? join(', ', @{$reg->{$m}->{rules}->{returns}}) : $reg->{$m}->{rules}->{returns};
					my $accepts = ref $reg->{$m}->{rules}->{accepts} eq 'ARRAY' ? join(', ', @{$reg->{$m}->{rules}->{accepts}}) : $reg->{$m}->{rules}->{accepts};
					my $is = ref $reg->{$m}->{rules}->{is} eq 'ARRAY' ? join(', ', @{$reg->{$m}->{rules}->{is}}) : $reg->{$m}->{rules}->{is};
					
					$t2->row($c, $regex, uc($m), $accepts, $returns, $is);
				}
			}
		}
	
		$t2->hr('bottom');
	} else {
		$self->log->info('-- No routes available ! --');
	}

	$self->log->info(' ');
}

$Leyland::CODES = {
	200 => ['OK', 'Standard response for successful HTTP requests.'],
	201 => ['Created', 'The request has been fulfilled and resulted in a new resource being created.'],
	202 => ['Accepted', 'The request has been accepted for processing, but the processing has not been completed.'],
	204 => ['No Content', 'The server successfully processed the request, but is not returning any content.'],
	
	300 => ['Multiple Choices', 'Indicates multiple options for the resource that the client may follow.'],
	301 => ['Moved Permanently', 'This and all future requests should be directed to the given URI.'],
	302 => ['Found', 'Temporary redirect.'],
	303 => ['See Other', 'The response to the request can be found under another URI using a GET method.'],
	304 => ['Not Modified', 'Indicates the resource has not been modified since last requested.'],
	307 => ['Temporary Redirect', 'The request should be repeated with another URI, but future requests can still use the original URI.'],
	
	400 => ['Bad Request', 'The request cannot be fulfilled due to bad syntax.'],
	401 => ['Unauthorized', 'Similar to 403 Forbidden, but specifically for use when authentication is possible but has failed or not yet been provided.'],
	403 => ['Forbidden', 'The request was a legal request, but the server is refusing to respond to it.'],
	404 => ['Not Found', 'The requested resource could not be found but may be available again in the future.'],
	405 => ['Method Not Allowed', 'A request was made of a resource using a request method not supported by that resource.'],
	406 => ['Not Acceptable', 'The requested resource is only capable of generating content not acceptable according to the Accept headers sent in the request.'],
	408 => ['Request Timeout', 'The server timed out waiting for the request.'],
	409 => ['Conflict', 'Indicates that the request could not be processed because of conflict in the request, such as an edit conflict.'],
	410 => ['Gone', 'Indicates that the resource requested is no longer available and will not be available again.'],
	411 => ['Length Required', 'The request did not specify the length of its content, which is required by the requested resource.'],
	412 => ['Precondition Failed', 'The server does not meet one of the preconditions that the requester put on the request.'],
	413 => ['Request Entity Too Large', 'The request is larger than the server is willing or able to process.'],
	414 => ['Request-URI Too Long', 'The URI provided was too long for the server to process.'],
	415 => ['Unsupported Media Type', 'The request entity has a media type which the server or resource does not support.'],
	417 => ['Expectation Failed', 'The server cannot meet the requirements of the Expect request-header field.'],
	
	500 => ['Internal Server Error', 'A generic error message, given when no more specific message is suitable.'],
	501 => ['Not Implemented', 'The server either does not recognise the request method, or it lacks the ability to fulfill the request.'],
	503 => ['Service Unavailable', 'The server is currently unavailable (because it is overloaded or down for maintenance).'],
};

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
