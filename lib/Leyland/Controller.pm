package Leyland::Controller;

use Moose::Role;
use MooseX::ClassAttribute;
use namespace::autoclean;

class_has 'prefix' => (is => 'rw', isa => 'Str', default => '');
class_has 'routes' => (is => 'ro', isa => 'HashRef', predicate => 'has_routes', writer => '_set_routes');

sub add_route {
	my ($class, $methods, $regex, $code) = @_;

	my $meth = join('|', @$methods);

	my $routes = $class->routes;
	$routes->{$regex}->{$meth} = $code;
	$class->_set_routes($routes);
}

sub set_prefix {
	my ($class, $code) = @_;

	$class->prefix($code->());
}

1;
