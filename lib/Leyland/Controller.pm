package Leyland::Controller;

# ABSTRACT: Leyland controller base class

use Moose::Role;
use MooseX::ClassAttribute;
use namespace::autoclean;

=head1 NAME

Leyland::Controller - Leyland controller base class

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 CLASS METHODS

=head1 OBJECT METHODS

=cut

class_has 'prefix' => (is => 'rw', isa => 'Str', default => '');
class_has 'routes' => (is => 'ro', isa => 'Tie::IxHash', predicate => 'has_routes', writer => '_set_routes');

sub add_route {
	my ($class, $method, $regex, $code) = (shift, shift, shift, pop);

	my $rules = {};
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

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Controller

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Leyland>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Leyland>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Leyland>

=item * Search CPAN

L<http://search.cpan.org/dist/Leyland/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
