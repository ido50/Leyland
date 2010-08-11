use MooseX::Declare;

role Leyland::Controller {
	use Data::Dumper;
	has 'prefix' => (is => 'ro', isa => 'Str', default => 'root', writer => 'set_prefix');
	has 'routes' => (is => 'ro', isa => 'HashRef', predicate => 'has_routes', writer => '_set_routes');

	requires 'gen_routes';

	method BUILD {
		# create routes for this controller
		$self->gen_routes;
	}

	method add (Str $method, Str $route, CodeRef $code) {
		my $routes = $self->routes;
		$routes->{$route}->{$method} = $code;
		$self->_set_routes($routes);
	}
}

1;
