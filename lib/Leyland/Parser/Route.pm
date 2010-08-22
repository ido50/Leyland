package Leyland::Parser::Route;

use warnings;
use strict;
use base 'Devel::Declare::Parser';

use Devel::Declare::Interface;
Devel::Declare::Interface::register_parser(__PACKAGE__);

sub rewrite {
	my $self = shift;

	my @parts = @{$self->parts};
	my @new_parts = ();

	$self->bail('You must define a route regex for the route method.') if scalar @parts == 0;

	# get the route regex
	my $route = shift(@parts)->[0];
	my $re = eval { qr{$route} };
	$self->bail("Could not parse route regex $route.") unless $re;
	push(@new_parts, [$re, undef]);

	# do we have 'accepts' and/or 'returns' rules?
	while (scalar @parts > 1) {
		my ($key, $value) = (shift(@parts)->[0], shift(@parts)->[0]);
		if ($key eq 'accepts' || $key eq 'returns' || $key eq 'speaks') {
			push(@new_parts, [$key.'='.$value, undef]);
		} else {
			$self->bail("I can't understand rule $key.");
		}
	}

	$self->new_parts(\@new_parts);
}

sub inject {('my ($self, $c) = (shift, shift);')}

1;
