package Leyland::Controller;

use Moose::Role;
use MooseX::ClassAttribute;
use namespace::autoclean;

class_has 'prefix' => (is => 'rw', isa => 'Str', default => '');
class_has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

sub add_route {
	my ($class, $method, $regex, $code) = (shift, shift, shift, pop);

	my $rules;
	while (scalar @_) {
		my ($key, $value) = split(/=/, shift);
		if (defined $key && defined $value) {
			$rules->{$key} = [split(/\|/, $value)];
		}
	}

	my $routes = $class->has_routes ? $class->routes : Tie::IxHash->new;
	
	if ($routes->EXISTS($regex)) {
		my $thing = $routes->FETCH($regex);
		$thing->{$method} = { class => $class, code => $code, rules => $rules };
	} else {
		$routes->Push($regex => { $method => { code => $code, rules => $rules } });
	}
	
	$class->_set_routes($routes);
}

sub set_prefix {
	my ($class, $code) = @_;

	$class->prefix($code->());
}

1;
