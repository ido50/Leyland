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

	$rules->{accepts} ||= ['text/html'];
	$rules->{returns} ||= ['text/html'];
	$rules->{is} ||= ['external'];
	
	# if this is a POST route, make sure it accepts application/x-www-form-urlencoded
	my $xwfu;
	foreach (@{$rules->{accepts}}) {
		if ($_ eq 'application/x-www-form-urlencoded') {
			$xwfu = 1;
			last;
		}
	}
	push(@{$rules->{accepts}}, 'application/x-www-form-urlencoded')
		if ($method eq 'post' && !$xwfu);

	my $routes = $class->has_routes ? $class->routes : Tie::IxHash->new;
	
	if ($routes->EXISTS($regex)) {
		my $thing = $routes->FETCH($regex);
		$thing->{$method} = { class => $class, code => $code, rules => $rules };
	} else {
		$routes->Push($regex => { $method => { class => $class, code => $code, rules => $rules } });
	}
	
	$class->_set_routes($routes);
}

sub set_prefix {
	my ($class, $code) = @_;

	$class->prefix($code->());
}

sub auto { 1 }

sub pre_route { 1 }

sub pre_template { 1 }

sub post_route { 1 }

1;
