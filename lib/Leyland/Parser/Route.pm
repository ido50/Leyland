package Leyland::Parser::Route;

use warnings;
use strict;
use base 'Devel::Declare::Parser';

use Devel::Declare::Interface;
Devel::Declare::Interface::register_parser(__PACKAGE__);

sub rewrite {
	my $self = shift;

	my $parts = $self->parts;

	$self->bail('No route') if scalar @$parts == 0;
	$self->bail('Too many arguments') if scalar @$parts > 1;

	my $re = eval { qr{$parts->[0]->[0]} };
	$self->bail('Could not parse route') unless $re;

	$self->new_parts([[$re, undef]]);
}

sub inject {('my $c = shift;')}

1;
