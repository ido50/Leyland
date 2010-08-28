package Leyland::View;

use Moose::Role;
use namespace::autoclean;
use Encode;

requires 'render';

around 'render' => sub {
	my ($orig, $self) = (shift, shift);

	return Encode::encode('utf8', $self->$orig(@_));
};

1;
