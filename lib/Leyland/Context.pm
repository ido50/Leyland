package Leyland::Context;

use Moose;
use namespace::autoclean;
use Plack::Request;
use Plack::Response;
use Leyland::Exception;
use Encode;
use Carp;

has 'leyland' => (is => 'ro', isa => 'Leyland', required => 1);

has 'env' => (is => 'ro', isa => 'HashRef', required => 1);

has 'views' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

has 'config' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'req' => (is => 'ro', isa => 'Plack::Request', lazy_build => 1);

has 'res' => (is => 'ro', isa => 'Plack::Response', default => sub { Plack::Response->new(200) });

has 'routes' => (is => 'ro', isa => 'ArrayRef[HashRef]', predicate => 'has_routes', writer => '_set_routes');

has 'log' => (is => 'ro', isa => 'Object', writer => '_set_log');

has 'wanted_mimes' => (is => 'ro', isa => 'ArrayRef[HashRef]', builder => '_build_mimes');

has 'current_route' => (is => 'rw', isa => 'Int', default => 0);

has 'pass_next' => (is => 'ro', isa => 'Bool', default => 0, writer => '_pass');

has 'stash' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'controller' => (is => 'ro', isa => 'Str', writer => '_set_controller');

has 'session' => (is => 'ro', isa => 'HashRef', predicate => 'has_session');

has 'json' => (is => 'ro', isa => 'Object', required => 1); # 'isa' should be 'JSON::Any', but for some reason JSON::Any->new blesses an array-ref, so validation fails

has 'xml' => (is => 'ro', isa => 'XML::TreePP', required => 1);

has 'died' => (is => 'ro', isa => 'Bool', default => 0, writer => '_set_died');

sub _build_req {
	my $self = shift;

	Plack::Request->new($self->env);
}

sub pass {
	my $self = shift;

	if ($self->routes->[$self->current_route + 1]) {
		my $new_route = $self->current_route + 1;
		$self->current_route($new_route);
		$self->_pass(1);
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

sub template {
	Encode::encode('utf8', shift->render(@_));
}

sub _build_mimes {
	my $self = shift;

	my @wanted_mimes;

	my $accept = $self->req->header('Accept');
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

sub forward {
	my ($self, $path) = (shift, shift);

	croak "500 Internal Server Error" unless $path;

	my @routes = $self->leyland->conneg->find_routes($self, $self->leyland->routes, $path);

	croak "500 Internal Server Error" unless scalar @routes;

	# just invoke the first matching route
	return $routes[0]->{route}->{code}->($self, @{$routes[0]->{route}->{captures}}, @_);
}

sub loc {
	shift->leyland->localizer->loc(@_);
}

sub exception {
	Leyland::Exception->throw($_[1]);
}

sub uri_for {
	my ($self, @args) = @_;

	my $params = pop @args if scalar @args;
	if ($params && ref $params ne 'HASH') {
		push(@args, $params);
		undef $params;
	}
	
	foreach (@args) {
		s!^/!!;
	}

	my $uri = $self->req->base;
	$uri   .= join('/', @args) if scalar @args;
	if ($params && ref $params eq 'HASH') {
		$uri .= '?' . join('&', map($_.'='.$params->{$_}, keys %$params));
	}

	return URI->new($uri);
}

__PACKAGE__->meta->make_immutable;
