package Leyland::Controller;

use Moose::Role;
use MooseX::ClassAttribute;
use namespace::autoclean;

class_has 'prefix' => (is => 'rw', isa => 'Str', default => '');
class_has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

sub add_route {
	my ($class, $methods, $regex, $code) = @_;

	my $meth = join('|', @$methods);

	my $routes = $class->has_routes ? $class->routes : Tie::IxHash->new;
	
	if ($routes->EXISTS($regex)) {
		my $thing = $routes->FETCH($regex);
		$thing->{$meth} = $code;
	} else {
		$routes->Push($regex => { $meth => $code });
	}
	
	$class->_set_routes($routes);
}

sub set_prefix {
	my ($class, $code) = @_;

	$class->prefix($code->());
}

1;
