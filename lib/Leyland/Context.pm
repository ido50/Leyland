package Leyland::Context;

# ABSTRACT: The working environment of an HTTP request and Leyland response

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

use Carp;
use Data::Dumper;
use Leyland::Exception;
use Module::Load;
use Text::SpanningTable;

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

has 'views' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

has 'res' => (is => 'ro', isa => 'Plack::Response', lazy_build => 1);

has 'routes' => (is => 'ro', isa => 'ArrayRef[HashRef]', predicate => 'has_routes', writer => '_set_routes');

has 'wanted_mimes' => (is => 'ro', isa => 'ArrayRef[HashRef]', builder => '_build_mimes');

has 'want' => (is => 'ro', isa => 'Str', writer => '_set_want');

has 'lang' => (is => 'ro', isa => 'Str', writer => 'set_lang');

has 'current_route' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_current_route');

has 'stash' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'controller' => (is => 'ro', isa => 'Str', writer => '_set_controller');

has 'user' => (is => 'ro', isa => 'Any', predicate => 'has_user', writer => 'set_user', clearer => 'clear_user');

has '_pass_next' => (is => 'ro', isa => 'Bool', default => 0, writer => '_set_pass_next');

sub leyland { shift->app }

sub log { shift->app->log }

sub xml { shift->app->xml }

sub json { shift->app->json }

sub config { shift->app->config }

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
	$self->res->headers($headers) if $headers && ref $headers eq 'ARRAY';
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
