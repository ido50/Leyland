package Leyland::Context;

# ABSTRACT: The working environment of an HTTP request and Leyland response

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

use Carp;
use Data::Dumper;
use JSON::Any;
use Leyland::Exception;
use Module::Load;
use Text::SpanningTable;
use XML::TreePP;

extends 'Plack::Request';

=head1 NAME

Leyland::Context - The working environment of an HTTP request and Leyland response

=head1 EXTENDS

L<Plack::Request>

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 CLASS METHODS

=head1 OBJECT METHODS

=cut

has 'app' => (is => 'ro', isa => 'Leyland', required => 1);

has 'cwe' => (is => 'ro', isa => 'Str', default => $ENV{PLACK_ENV});

has 'num' => (is => 'ro', isa => 'Int', default => 0);

has 'res' => (is => 'ro', isa => 'Plack::Response', lazy_build => 1);

has 'routes' => (is => 'ro', isa => 'ArrayRef[HashRef]', predicate => 'has_routes', writer => '_set_routes');

has 'wanted_mimes' => (is => 'ro', isa => 'ArrayRef[HashRef]', builder => '_build_mimes');

has 'want' => (is => 'ro', isa => 'Str', writer => '_set_want');

has 'lang' => (is => 'ro', isa => 'Str', writer => 'set_lang');

has 'current_route' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_current_route');

has 'stash' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'controller' => (is => 'ro', isa => 'Str', writer => '_set_controller');

has 'user' => (is => 'ro', isa => 'Any', predicate => 'has_user', writer => 'set_user', clearer => 'clear_user');

has 'json' => (is => 'ro', isa => 'Object', default => sub { JSON::Any->new(utf8 => 1) }); # 'isa' should be 'JSON::Any', but for some reason JSON::Any->new blesses an array-ref, so validation fails

has 'xml' => (is => 'ro', isa => 'XML::TreePP', default => sub { my $xml = XML::TreePP->new(); $xml->set(utf8_flag => 1); return $xml; });

has '_pass_next' => (is => 'ro', isa => 'Bool', default => 0, writer => '_set_pass_next');

has '_data' => (is => 'ro', isa => 'Any', predicate => '_has_data', writer => '_set_data');

sub leyland { shift->app }

sub log { shift->app->log }

sub config { shift->app->config }

sub views { shift->app->views }

sub params { shift->parameters }

sub data {
	my $self = shift;

	return unless $self->content_type;

	return $self->_data if $self->_has_data;

	if ($self->content_type eq 'application/json') {
		$self->_set_data($self->json->from_json($self->content));
		return $self->_data;
	} elsif ($self->content_type eq 'application/atom+xml' || $self->content_type eq 'application/xml') {
		$self->_set_data($self->xml->parse($self->content));
		return $self->_data;
	}

	return;
}

sub pass {
	my $self = shift;

	# do not allow passing if we don't have routes to pass to
	if ($self->current_route + 1 < scalar @{$self->routes}) {
		$self->_set_current_route($self->current_route + 1);
		$self->_set_pass_next(1);
		return 1;
	}

	return 0;
}

sub view {
	my ($self, $name) = @_;

	foreach (@{$self->views} || ()) {
		next unless $_->name eq $name;
		return $_;
	}

	croak "Can't find a view named $name.";
}

sub render {
	my ($self, $tmpl_name, $context, $use_layout) = @_;

	# first, run the pre_template sub
	$self->controller->pre_template($self, $tmpl_name, $context, $use_layout);

	# allow passing $use_layout but not passing $context
	if (defined $context && ref $context ne 'HASH') {
		$use_layout = $context;
		$context = {};
	}

	# default $use_layout to 1
	$use_layout = 1 unless defined $use_layout;

	$context->{c} = $self;
	$context->{l} = $self->leyland;
	foreach (keys %{$self->stash}) {
		$context->{$_} = $self->stash->{$_} unless exists $context->{$_};
	}

	return unless scalar @{$self->views};

	return $self->views->[0]->render($tmpl_name, $context, $use_layout);
}

sub template { shift->render(@_) }

sub structure {
	my ($self, $obj, $want) = @_;
	
	if ($want eq 'application/json') {
		return $self->json->to_json($obj);
	} elsif ($want eq 'application/atom+xml' || $want eq 'application/xml') {
		return $self->xml->write($obj);
	} else {
		# just use Data::Dumper
		return Dumper($obj);
	}
}

sub forward {
	my ($self, $path) = (shift, shift);

	$self->exception({ code => 500, error => "You must provide a path to forward to" }) unless $path;

	my $method;

	if ($path =~ m/^(GET|POST|PUT|DELETE|HEAD|OPTIONS):/) {
		$method = $1;
		$path = $';

		$self->log->info("Attempting to forward request to $path with a $method method.");
	} else {
		$self->log->info("Attempting to forward request to $path with any method.");
	}

	my @routes = Leyland::Negotiator->just_routes($self, {
		app_routes => $self->app->routes,
		path => $path,
		method => $method,
		internal => 1
	});

	$self->exception({ code => 500, error => "Can't forward as no matching routes were found" }) unless scalar @routes;

	my @pass = ($routes[0]->{class}, $self);
	push(@pass, @{$routes[0]->{captures}}) if scalar @{$routes[0]->{captures}};
	push(@pass, @_) if scalar @_;

	# just invoke the first matching route
	return $routes[0]->{code}->(@pass);
}

sub loc {
	my ($self, $msg, @args) = @_;

	return $self->app->localizer->loc($msg, $self->lang, @args);
}

sub exception {
	my ($self, $err) = @_;

	$err->{location} = $err->{location}->as_string
		if $err->{location} && ref $err->{location} =~ m/^URI/;

	Leyland::Exception->throw($err);
}

sub uri_for {
	my ($self, $path, $args) = @_;

	my $uri = $self->base;
	my $full_path = $uri->path . $path;
	$full_path =~ s!^/!!; # remove starting slash
	$uri->path($full_path);
	$uri->query_form($args) if $args;

	return $uri;
}

sub finalize { 1 } # meant to be overridden

=head1 INTERNAL METHODS

The following methods are only to be used internally.

=cut

sub _build_res { shift->new_response(200, [ 'Content-Type' => 'text/html' ]) }

sub _build_mimes {
	my $self = shift;

	my @wanted_mimes;

	my $accept = $self->header('Accept');
	if ($accept) {
		my @mimes = split(/, ?/, $accept);
		foreach (@mimes) {
			my ($mime, $q) = split(/;q=/, $_);
			$q = 1 unless defined $q;
			push(@wanted_mimes, { mime => $mime, q => $q });
		}
		@wanted_mimes = reverse sort { $a->{q} <=> $b->{q} } @wanted_mimes;
		return \@wanted_mimes;
	} else {
		return [];
	}
}

sub _respond {
	my ($self, $status, $headers, $content) = @_;

	$self->res->status($status) if $status && $status =~ m/^\d+$/;
	$self->res->headers($headers) if $headers && ref $headers eq 'HASH';
	if ($content) {
		my $body = Encode::encode('UTF-8', $content);
		$self->res->body($body);
		$self->res->content_length(length($body));
	}

	$self->_log_response;

	return $self->res->finalize;
}

sub _log_request {
	my $self = shift;

	my $t = Text::SpanningTable->new(20, 20, 12, 20, 28);

	$self->stash->{_tft} = $t;

	$self->log->info($t->hr('top'));
	$self->log->info($t->row('Request #', 'Address', 'Method', 'Path', 'Content-Type'));
	$self->log->info($t->dhr);
	foreach (split(/\n/, $t->row($self->num, $self->address, $self->method, $self->path, $self->content_type))) {
		$self->log->info($_);
	}
	$self->log->info($t->hr);

	$self->log->set_exec(sub { $_[0]->stash->{_tft}->row([5, $_[1]]) }, $self);
}

sub _log_response {
	my $self = shift;

	my $t = $self->stash->{_tft};
	
	$self->log->clear_exec();
	$self->log->clear_args();

	$self->log->info($t->hr);
	foreach (split(/\n/, $t->row($self->num, $self->res->status.' '.$Leyland::CODES->{$self->res->status}->[0], [3, $self->res->content_type]))) {
		$self->log->info($_);
	}
	$self->log->info($t->dhr);
	$self->log->info($t->row('Response #', 'Status', [3, 'Content-Type']));
	$self->log->info($t->hr('bottom'));
	$self->log->info(' ');
}

sub _invoke_route {
	my $self = shift;

	my $i = $self->current_route;

	$self->_set_controller($self->routes->[$i]->{class});
	
	# but first invoke all 'auto' subs up to the matching route's controller
	foreach ($self->_route_parents($self->routes->[$i])) {
		$_->auto($self, @{$self->routes->[$i]->{captures}});
	}

	# then invoke the pre_route subroutine
	$self->controller->pre_route($self, @{$self->routes->[$i]->{captures}});

	# invoke the route itself
	$self->_set_want($self->routes->[$i]->{media});
	my $ret = $self->_serialize(
		$self->routes->[$i]->{code}->($self->controller, $self, @{$self->routes->[$i]->{captures}}),
		$self->routes->[$i]->{media}
	);

	# invoke the post_route subroutine
	$self->controller->post_route($self, \$ret);

	return $ret;
}

sub _serialize {
	my ($self, $obj, $want) = @_;

	my $ct = $self->res->content_type;
	unless ($ct) {
		$ct = $want.'; charset=UTF-8' if $want && $want =~ m/text|json|xml|html|atom/;
		$ct ||= 'text/plain; charset=UTF-8';
		$self->log->info($ct .' will be returned');
		$self->res->content_type($ct);
	}

	if (ref $obj && ref $obj eq 'ARRAY' && (scalar @$obj == 2 || scalar @$obj == 3) && ref $obj->[0] eq 'HASH') {
		# render specified template
		if ((exists $obj->[0]->{$want} && $obj->[0]->{$want} eq '') || !exists $obj->[0]->{$want}) {
			# empty string for template name means deserialize
			# same goes if the route returns the wanted type
			# but has no template rule for it
			return $self->structure($obj->[1], $want);
		} else {
			my $use_layout = scalar @$obj == 3 && defined $obj->[2] ? $obj->[2] : 1;
			return $self->template($obj->[0]->{$want}, $obj->[1], $use_layout);
		}
	} elsif (ref $obj && (ref $obj eq 'ARRAY' || ref $obj eq 'HASH')) {
		# serialize according to wanted type
		return $self->structure($obj, $want);
	} elsif (ref $obj) {
		# $obj is some kind of reference, use Data::Dumper;
		Dumper($obj);
	} else {
		# $obj is a scalar, return as is
		return $obj;
	}
}

sub _route_parents {
	my ($self, $route) = @_;

	my @parents;

	my $class = $route->{class};
	while ($class =~ m/Controller::(.+)$/) {
		# attempt to find a controller for this class
		foreach ($self->app->controllers) {
			if ($_ eq $class) {
				push(@parents, $_);
				last;
			}
		}
		# now strip the class once
		$class =~ s/::[^:]+$//;
	}
	$class .= '::Root';
	push(@parents, $class);

	return @parents;
}

sub FOREIGNBUILDARGS {
	my ($class, %args) = @_;

	return ($args{env});
}

sub BUILD { shift->_log_request }

override 'content' => sub { Encode::decode('UTF-8', super()) };

override 'session' => sub { super() || {} };

override '_uri_base' => sub {
	my $base = super();
	$base .= '/' unless $base =~ m!/$!;
	return $base;
};

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Context

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
