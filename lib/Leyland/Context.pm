package Leyland::Context;

use Moose;
use namespace::autoclean;
use Plack::Request;
use Plack::Response;
use Log::Handler;
use Carp;

has 'env' => (is => 'ro', isa => 'HashRef', required => 1);

has 'log' => (is => 'ro', isa => 'Log::Handler', required => 1);

has 'views' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

has 'config' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'req' => (is => 'ro', isa => 'Plack::Request', lazy_build => 1);

has 'res' => (is => 'ro', isa => 'Plack::Response', default => sub { Plack::Response->new(200) });

has 'routes' => (is => 'ro', isa => 'ArrayRef[HashRef]', predicate => 'has_routes', writer => '_set_routes');

has 'current_route' => (is => 'rw', isa => 'Int', default => 0);

has 'pass_next' => (is => 'ro', isa => 'Bool', default => 0, writer => '_pass');

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

__PACKAGE__->meta->make_immutable;
