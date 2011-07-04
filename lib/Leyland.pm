package Leyland;

# ABSTRACT: Plack-based framework for RESTful web applications

our $VERSION = "0.001006";
$VERSION = eval $VERSION;

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

Leyland - Plack-based framework for RESTful web applications

=head1 SYNOPSIS

	# in app.psgi:

	#!/usr/bin/perl -w

	use strict;
	use warnings;
	use MyApp;

	my $config = {
		app => 'MyApp',
		views => ['Tenjin'],
		locales => './i18n',
	};

	my $myapp = MyApp->new(config => $config);

	my $app = sub {
		$myapp->handle(shift);
	};

=head1 DESCRIPTION

Leyland is a L<Plack>-based application framework for building truely
RESTful, MVC-style web applications.

"Another application framework?" you ask? Well yes! You see, after several
years of L<Catalyst> development, I grew tired of Catalyst's bloat, and
the fact that it made it very hard (pretty much impossible if you ask me)
to create truely RESTful applications. I then moved for a short while to
L<Dancer>, which had a nice syntax for defining routes and had at least some REST properties,
but I quickly found it didn't fit my needs as well, and that it also made
it very difficult to write truely RESTful applications. I also really missed
Catalyst's "context object" and some of its other features, and simply
couldn't get used to Dancer's whole functional syntax you're supposed to
use inside your routes. While there were quite a few other options on CPAN,
I didn't like any of them, plus pretty much none of them were native Plack
frameworks, which for me is a bit of a minus (can't blame them though as
most of them predate Plack), so I decided to create my own framework,
based on Plack and designed to my liking. This is the mess that I've created.
You will find that it mostly resembles Catalyst, while providing a syntax
mostly similar to Dancer, but with a lot of crazy ideas of its own.

=head2 FEATURES

=over

=item * Build truely RESTful web applications - Leyland was designed from
the ground up according to the Representational State Transfer style of
software architecture. Leyland applications perform real HTTP negotiations,
(can) provide different representations of the same resource easily, respond
with proper HTTP status codes, throw real HTTP exceptions, etc.

=item * Automatic data (de)serialization - Leyland does by itself the boring task
of serializing resources to representations in the format your client
wants to receive, like JSON and XML. It will also deserialize JSON/XML
requests to Perl data-structures automatically.

=item * Pure UTF-8 - Leyland applications are pure UTF-8. Anything your
application receives is automatically UTF-8 decoded, and anything your
application sends is automatically UTF-8 encoded. Leyland apps will not
accept, nor provide, content in a different character set. If you want to
use different/multiple encodings, then Leyland is not for you.

=item * Localize for the client, not the server - Pretty much every other
application framework only concerns itself with localizing the application
to the locale of the machine on which it is running. I find that this is
rarely useful nor interesting to the application developer. Leyland localizes for
the client, not the server. If the client wants to view your application
(which may be a simple website) in Hebrew, and your application supports
Hebrew, then you can easily provide him with Hebrew representations.
Leyland uses L<Locale::Wolowitz> for this purpose.

=item * Easy deployment and middleware support via L<Plack> - Leyland doesn't
support Plack, it is dependant on it. Leyland's entire session support,
for example, depends on Plack's L<Session|Plack::Middleware::Session>
middleware. Use the full power of Plack in your Leyland application.

=item * Less code, better programs - One thing I really hated about Catalyst
was that I had to create stupid pointless classes that don't do anything
but wrap a base class, just so I can have a new view class or something.
While not as lightweight as Dancer, Leyland does a lot of the boring work
for you, so you can concentrate more on your application.

=item * Flexible, extensible, unbreakable - Well, it's not unbreakable,
but Leyland was designed to be as flexible and as extensible as possible - where
flexibility matters, and strict - where constistency and convention are appropriate.
Leyland goes to great lengths to give you the ability to do things the
way you want to, and more importantly - the way your end-users want to.
Your applications listen to your users' preferences and automatically decide on a
suitable course of action. Leyland is also L<Moose> based, making it easy
to extend and tweak its behavior.

=item * Doesn't have a pony - You don't really need a pony, do you?

=back

=head2 STATUS

Development of Leyland began August 2010. I have been using it extensively
for several projects, some of them already in production. Therefore, the
API has somewhat stabilized and I do not consider it in alpha status.
That said, Leyland still is immature, and I cannot guarantee that API
changes won't be made, nor that it is bug free or even secure enough. If
you're thinking of using Leyland for a production project, please test it
thoroughly beforehand.

=head2 MANUAL / TUTORIAL / GUIDE / GIBBERISH

To learn about using Leyland, please refer to the L<Leyland::Manual>. The
documentation of this distribution's classes is for reference only, the
manual is where you're most likely to find your answers. Or not.

=head2 WHAT'S WITH THE NAME?

Leyland is named after Mr. Bean's clunker of a car - the British Leyland
Mini 1000. I don't know why.

=head1 ATTRIBUTES

=head2 config

A hash-ref of configuration options for the application. If not provided,
a default configuration will be used.

=head2 context_class

The name of the class to be used as the context class for every request.
Defaults to L<Leyland::Context>. If provided, the class must extend
Leyland::Context.

=head2 name

The package name of the application, for example C<MyApp> or C<My::App>.
Automatically created from the app's configuration. If config doesn't
define a name, 'Leyland' will be used.

=head2 log

A logger object that C<does> L<Leyland::Logger>, providing the application
with logging capabilities. Automatically built from the app's config, unless
config doesn't define a logger, in which case L<Leyland::Logger::STDERR>
will be used.

=head2 localizer

If application config defines a path for localization files, this will hold
a L<Leyland::Localizer> object, which is based on L<Locale::Wolowitz>.

=head2 views

An array refernce of all L<Leyland::View> classes enabled in the app's
configuration. If none defined, L<Tenjin> is used by default.

=head2 routes

A L<Tie::IxHash> object holding all routes defined in the application's
controllers. Automatically created, not to be used directly by applications.

=head2 req_counter

An integer representing the number of requests handled by the application.
Automatically created.

=head2 cwe

The plack environment in which the application is running. This is the
C<PLACK_ENV> environment variable. Defaults to "development" unless you've
provided a specific value to C<plackup> (via the C<-E> switch or by
changing C<PLACK_ENV> directly).

=cut

has 'config' => (is => 'ro', isa => 'HashRef', default => sub { __PACKAGE__->_default_config });

has 'context_class' => (is => 'ro', isa => 'Str', default => 'Leyland::Context');

has 'name' => (is => 'ro', isa => 'Str', required => 1);

has 'log' => (is => 'ro', does => 'Leyland::Logger', writer => '_set_log');

has 'localizer' => (is => 'ro', isa => 'Leyland::Localizer', predicate => 'has_localizer', writer => '_set_localizer');

has 'views' => (is => 'ro', isa => 'ArrayRef', predicate => 'has_views', writer => '_set_views');

has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

has 'req_counter' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_req_counter');

has 'cwe' => (is => 'ro', isa => 'Str', default => $ENV{PLACK_ENV});

=head1 CLASS METHODS

=head2 new( [ %attrs ] )

Creates a new instance of this class. None of the attributes are required
(in fact, you shouldn't pass most of them), but you will mostly pass
the C<config> attribute, and possibly the C<context_class> attribute.

=head1 OBJECT METHODS

=head2 setup()

Meant to be overridden by applications, this is automatically called
right after the application has been initialized, so it is useful for
one-time initializations your application might need to perform. If not
overridden, this method does nothing.

=cut

sub setup { 1 }

=head2 handle( \%env )

Receives a Plack environment hash-ref of an HTTP request, creates a new
instance of the application's context class (most probably L<Leyland::Context>),
performs HTTP negotiations and finds routes matching the request. If any
are found, the first one is invoked and an HTTP response is generated and
returned.

You should note that requests to paths that end with a slash will automatically
be redirected without the trailing slash.

This method will probably be called from C<app.psgi>.

=cut

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
				$c->_set_pass_next(0);
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

=head2 has_localizer()

Returns a true value if the application has a localizer.

=head2 has_views()

Returns a true value if the application has any view classes.

=head2 has_routes()

Returns a true value if the application has any routes defined in its
controllers.

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

	$opts{name} = $opts{config} ? $opts{config}->{app} : 'MyApp';

	# create the object
	return $class->$orig(%opts);
};

=head2 BUILD()

Automatically called by L<Moose> after instance creation, this method
loads the context class, application logger, localizer, controllers and
views. It then find all routes in the controllers, runs the application's
setup() method, and prints a nice info table to the log.

=cut

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
	$self->_set_localizer(Leyland::Localizer->new(path => $self->config->{locales}))
		if exists $self->config->{locales};

	# require Module::Pluggable and load all views and controllers
	# with it
	load Module::Pluggable;
	Module::Pluggable->import(
		search_path => [$self->config->{app}.'::View'],
		sub_name => '_views',
		instantiate => 'new'
	);
	Module::Pluggable->import(
		search_path => [$self->config->{app}.'::Controller'],
		sub_name => 'controllers',
		require => 1
	);

	# init views, if any, start with view modules in the app
	my @views = $self->_views;
	# now load views defined in the config file
	VIEW: foreach (@{$self->config->{views} || []}) {
		# have we already loaded this view in the first step?
		foreach my $v ($self->_views) {
			next VIEW if blessed($v) eq $_;
		}

		# attempt to load this view
		my $class = "Leyland::View::$_";
		load $class;
		push(@views, $class->new());
	}
	$self->_set_views(\@views) if scalar @views;
	# if we haven't loaded any views, load Tenjin
	unless (scalar @views) {
		load Leyland::View::Tenjin;
		$self->_set_views([ Leyland::View::Tenjin->new ]);
	}

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

=head2 _handle_exception( $c, $exp )

Receives exceptions thrown by the application (including run-time errors)
and generates an HTTP response with the error information, in a format
recognizable by the client.

=cut

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

	# are we on the development environment? if so, and the exception
	# has no mimes, we croak with a simple error message so that Plack
	# displays a nice stack trace
	croak $self->name.' croaked with HTTP status code '.$exp->code.' and error message "'.$err.'"'
		if $self->cwe eq 'development' && !$exp->has_mimes;

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
		) if $_->{mime} eq 'text/html' || $_->{mime} eq 'application/xhtml+xml' || $_->{mime} eq 'application/json' || $_->{mime} eq 'application/atom+xml' || $_->{mime} eq 'application/xml';
	}

	# We do not support none of the MIME types the client wants,
	# let's return plain text
	return $c->_respond(
		$exp->code,
		{ 'Content-Type' => 'text/plain; charset=UTF-8' },
		Dumper($exp->error)
	);
}

=head2 _default_config()

Returns a default configuration hash-ref.

=cut

sub _default_config { { app => 'Leyland', views => ['Tenjin'] } }

=head2 _autolog( $msg )

Used by C<Text::SpanningTable> when printing the application's info
table.

=cut

sub _autolog { $_[0]->info($_[1]) }

=head2 _initial_debug_info()

Prints an info table of the application after initialization.

=cut

sub _initial_debug_info {
	my $self = shift;

	my @views;
	foreach (sort @{$self->views || []}) {
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
				my $reg = $pre->FETCH($r);
				foreach my $m (sort keys %$reg) {
					my $returns = ref $reg->{$m}->{rules}->{returns} eq 'ARRAY' ? join(', ', @{$reg->{$m}->{rules}->{returns}}) : $reg->{$m}->{rules}->{returns};
					my $accepts = ref $reg->{$m}->{rules}->{accepts} eq 'ARRAY' ? join(', ', @{$reg->{$m}->{rules}->{accepts}}) : $reg->{$m}->{rules}->{accepts};
					my $is = ref $reg->{$m}->{rules}->{is} eq 'ARRAY' ? join(', ', @{$reg->{$m}->{rules}->{is}}) : $reg->{$m}->{rules}->{is};
					
					$t2->row($c, $r, uc($m), $accepts, $returns, $is);
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

=head1 ACKNOWLEDGMENTS

I wish to thank the following people:

=over

=item * L<http://search.cpan.org/~sknpp/|Sebastian Knapp> for submitting bug fixes

=item * L<http://search.cpan.org/~mdorman/|Michael Alan Dorman> for some helpful ideas

=back

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

Copyright 2010-2011 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

__PACKAGE__->meta->make_immutable;
