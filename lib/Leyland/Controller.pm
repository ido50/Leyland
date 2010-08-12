package Leyland::Controller;

use Moose::Role;
use namespace::autoclean;

has 'prefix' => (is => 'ro', isa => 'Str', default => 'root', writer => 'set_prefix');
has 'routes' => (is => 'ro', isa => 'HashRef', predicate => 'has_routes', writer => '_set_routes');

requires 'gen_routes';

sub BUILD {
	my $self = shift;

	# create routes for this controller
	$self->gen_routes;
}

sub add {
	my ($self, $method, $route, $code) = @_;

	my $routes = $self->routes;
	$routes->{$route}->{$method} = $code;
	$self->_set_routes($routes);
}

1;
