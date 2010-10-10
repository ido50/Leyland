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
use Try::Tiny;
use Text::SimpleTable;

has 'config' => (is => 'ro', isa => 'HashRef', builder => '_init_config');

has 'logger' => (is => 'ro', does => 'Leyland::Logger', writer => '_set_logger');

has 'localizer' => (is => 'ro', does => 'Leyland::Localizer', predicate => 'has_localizer', writer => '_set_localizer');

has 'views' => (is => 'ro', isa => 'ArrayRef', predicate => 'has_views', writer => '_set_views');

has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

has 'futil' => (is => 'ro', isa => 'File::Util', default => sub { File::Util->new });

has 'json' => (is => 'ro', isa => 'Object', default => sub { JSON::Any->new }); # 'isa' should be 'JSON::Any', but for some reason JSON::Any->new blesses an array-ref, so validation fails

has 'xml' => (is => 'ro', isa => 'XML::TreePP', default => sub { my $xml = XML::TreePP->new(); $xml->set(utf8_flag => 1); return $xml; });

has 'conneg' => (is => 'ro', isa => 'Leyland::Negotiator', default => sub { Leyland::Negotiator->new });

has 'req_counter' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_req_counter');

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

	$config->{env} ||= 'development';

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

	# invoke setup method
	$self->setup();

	# print debug information
	$self->_initial_debug_info;
}

sub handle {
	my ($self, $env) = @_;

	# create the context object
	my %params = ( leyland => $self, env => $env, config => $self->config, json => $self->json, xml => $self->xml );
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

	# log this request
	$self->_log_request($c);

	# is this an OPTIONS request?
	if ($c->req->method eq 'OPTIONS') {
		my @options = $self->conneg->find_options($c, $self->routes);
		$c->res->status(204); # 204 No Content
		$c->res->header('Allow' => join(', ', @options));
		return $c->res->finalize;
	}

	# Leyland only supports UTF-8 character encodings, so let's check
	# the client supports that. If not, let's return an error
	$self->conneg->negotiate_charset($c);

	# find matching routes (will issue an error if none found or none
	# return client's acceptable media types)
	my @routes = try {
		$self->conneg->find_routes($c, $self->routes);
	} catch {
		($self->_handle_exception($c, $_));
	};
	return $routes[0] if $c->died;

	$c->_set_routes(\@routes);
	
	# invoke the first matching route
	my $i = 0;
	my $ret = try {
		$self->_invoke_route($c, $i);
	} catch {
		$self->_handle_exception($c, $_);
	};
	return $ret if $c->died;

	while ($c->pass_next && $i < scalar @{$c->routes} && $i < 100) { # $i is also used to prevent infinite loops
		# we need to pass to the next matching route.
		# first, let's erase the pass flag from the context
		# so we don't try to do this infinitely
		$c->_pass(0);
		
		$ret = try {
			$self->_invoke_route($c, $i);
		} catch {
			$self->_handle_exception($c, $_);
		};
		return $ret if $c->died;
		
		$i++;
	}

	$c->res->body($ret);

	print STDERR 'Response #'.$self->req_counter.': '.$c->res->status.' '.$Leyland::CODES->{$c->res->status}->[0].' ('.$c->res->header('Content-Type').")\n";

	return $c->res->finalize;
}

sub log {
	$_[0]->logger->logger;
}

sub setup {
	# meant to be overriden
}

sub _log_request {
	my ($self, $c) = @_;

	# increment the request counter
	$self->_set_req_counter($self->req_counter + 1);

	# send log message detailing the request
	$c->req->logger({ level => 'info', message => '-'x90 });
	$c->req->logger({ level => 'info', message => join(', ', 'Request #'.$self->req_counter, $c->req->address, DateTime->now->ymd, DateTime->now->hms) });
	my $msg = $c->req->method . ' ' . $c->req->path;
	$msg .= ' (' . $c->req->header('Content-Type') . ')' if $c->req->header('Content-Type');
	$c->req->logger({ level => 'info', message => $msg });
}

sub _invoke_route {
	my ($self, $c, $i) = @_;

	$c->_set_controller($c->routes->[$i]->{route}->{class});
	
	# but first invoke all 'auto' subs up to the matching route's controller
	foreach ($self->_route_parents($c->routes->[$i]->{route}->{prefix})) {
		$_->auto($c, @{$c->routes->[$i]->{route}->{captures}});
	}

	# then invoke the pre_route subroutine
	$c->controller->pre_route($c, @{$c->routes->[$i]->{route}->{captures}});

	# invoke the route itself
	my $ret = $self->_deserialize($c, $c->routes->[$i]->{route}->{code}->($c->controller, $c, @{$c->routes->[$i]->{route}->{captures}}), $c->routes->[$i]->{media});

	# invoke the post_route subroutine
	$c->controller->post_route($c, @{$c->routes->[$i]->{route}->{captures}});

	return $ret;
}

sub _handle_exception {
	my ($self, $c, $exp) = @_;
	
	$c->_set_died(1);
	
	croak $_ unless ref $_ && $_->isa('Leyland::Exception');

	$c->res->status($exp->code);

	# do we have templates for any of the client's requested MIME types?
	# if so, render the first one you find.
	if ($exp->has_mimes) {
		foreach (@{$c->wanted_mimes}) {
			if ($exp->has_mime($_->{mime})) {
				my $err = !ref $exp->error || ref $exp->error eq 'SCALAR' ? { error => $exp->error } : $exp->error;
				my $ret = $c->template($exp->mime($_->{mime}), $err, $exp->use_layout);
				$c->res->content_type($_->{mime}.';charset=UTF-8');
				$c->res->body($ret);
				return $c->res->finalize;
			}
		}
	}

	# we haven't found any templates for the request mime types, let's
	# attempt to deserialize the error ourselves if the client accepts
	# JSON or XML
	foreach (@{$c->wanted_mimes}) {
		if ($_->{mime} eq 'application/json' || $_->{mime} eq 'application/atom+xml' || $_->{mime} eq 'application/xml') {
			my $err = !ref $exp->error || ref $exp->error eq 'SCALAR' ? { error => $exp->error } : $exp->error;
			$c->res->content_type($_->{mime}.';charset=UTF-8');
			$c->res->body($self->_deserialize($c, $err, $_->{mime}));
			
			print STDERR 'Response #'.$self->req_counter.': '.$c->res->status.' '.$Leyland::CODES->{$c->res->status}->[0].' ('.$c->res->header('Content-Type').")\n";

			return $c->res->finalize;
		} elsif ($_->{mime} eq 'text/html' || $_->{mime} eq 'text/plain') {
			my $ret = !ref $exp->error || ref $exp->error eq 'SCALAR' ? $exp->error : Dumper($exp->error);
			$ret =~ s/^\$VAR1 = //;
			$ret =~ s/;$//;
			$c->res->content_type($_->{mime}.';charset=UTF-8');
			$c->res->body($ret);
			
			print STDERR 'Response #'.$self->req_counter.': '.$c->res->status.' '.$Leyland::CODES->{$c->res->status}->[0].' ('.$c->res->header('Content-Type').")\n";
			
			return $c->res->finalize;
		}
	}

	# We do not support none of the MIME types the client wants,
	# let's return plain text
	my $ret = !ref $exp->error || ref $exp->error eq 'SCALAR' ? $exp->error : Dumper($exp->error);
	$ret =~ s/^\$VAR1 = //;
	$ret =~ s/;$//;
	$c->res->content_type('text/plain;charset=UTF-8');
	$c->res->body($ret);

	print STDERR 'Response #'.$self->req_counter.': '.$c->res->status.' '.$Leyland::CODES->{$c->res->status}->[0].' ('.$c->res->header('Content-Type').")\n";

	return $c->res->finalize;
}

sub _deserialize {
	my ($self, $c, $obj, $want) = @_;

	my $ct = $want.';charset=UTF-8' if $want =~ m/text|json|xml|html|atom/;
	$c->res->content_type($ct);

	if (ref $obj eq 'ARRAY' && (scalar @$obj == 2 || scalar @$obj == 3) && ref $obj->[0] eq 'HASH') {
		# render specified template
		if ((exists $obj->[0]->{$want} && $obj->[0]->{$want} eq '') || !exists $obj->[0]->{$want}) {
			# empty string for template name means deserialize
			# same goes if the route returns the wanted type
			# but has no template rule for it
			return $c->structure($obj->[1], $want);
		} else {
			my $use_layout = scalar @$obj == 3 && defined $obj->[2] ? $obj->[2] : 1;
			return $c->template($obj->[0]->{$want}, $obj->[1], $use_layout);
		}
	} elsif (ref $obj eq 'ARRAY' || ref $obj eq 'HASH') {
		# deserialize according to wanted type
		return $c->structure($obj, $want);
	} else { # implied(?): ref $obj eq 'SCALAR'
		# return as is
		return $obj;
	}
}

sub _route_parents {
	my ($self, $prefix) = @_;
	
	my ($first, $last);
	
	my @parents;

	foreach ($self->controllers) {
		if ($_->prefix eq '') {
			$first = $_;
		} elsif ($_->prefix eq $prefix) {
			$last = $_;
		}
	}
	
	push(@parents, $first) if $first;

	while ($prefix) {
		$prefix =~ s!/[^/]+$!!;
		next unless $self->routes->EXISTS($prefix);
		
		# get the class
		foreach my $cont ($self->controllers) {
			if ($cont->prefix eq $prefix) {
				push(@parents, $cont);
				last;
			}
		}
	}

	push(@parents, $last) if $last;

	return @parents;
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
		logger => {
			class => 'LogShutton',
		},
		views => ['Tenjin'],
	}
}

sub _initial_debug_info {
	my $self = shift;

	my @views;
	foreach (sort @{$self->views}) {
		my $view = ref $_;
		$view =~ s/^Leyland::View:://;
		push(@views, $view);
	}

	my $logger = ref $self->logger;
	$logger =~ s/^Leyland::Logger:://;

	my $t1 = Text::SimpleTable->new(90);
	$t1->row($self->config->{app}. ' (powered by Leyland)');
	$t1->hr;
	$t1->row('Current environment: '.$self->config->{env});
	$t1->row('Avilable views: '.join(', ', @views));
	$t1->row('Logger: '.$logger);
	
	if ($self->has_localizer) {
		my $loc = ref $self->localizer;
		$loc =~ s/^Leyland::Localizer:://;
		$t1->row('Localizer: '.$loc);
	}

	print STDERR $t1->draw, "Available routes:\n";

	if ($self->has_routes) {
		my $t2 = Text::SimpleTable->new([12, 'Prefix'], [20, 'Regex'], [7, 'Method'], [14, 'Accepts'], [14, 'Returns'], [8, 'Is']);

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

		print STDERR $t2->draw;
	} else {
		print STDERR "-- No routes available ! --\n";
	}
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
