package Leyland::View::Tenjin;

# ABSTRACT: Tenjin view class for Leyland

use Moose;
use namespace::autoclean;
use Tenjin 0.070001;

=head1 NAME

Leyland::View::Tenjin - Tenjin view class for Leyland

=head1 SYNOPSIS

	# in app.psgi:
	my $config = {
		...
		views => ['Tenjin'],
		...
	};

=head1 DESCRIPTION

This module uses the L<Tenjin> template engine to render views. It is
the default view class used by <Leyland>.

=head1 CONSUMES

L<Leyland::View>

=head1 ATTRIBUTES

=head2 engine

The L<Tenjin> object used.

=cut

with 'Leyland::View';

has 'engine' => (is => 'ro', isa => 'Tenjin', builder => '_init_engine');

=head1 OBJECT METHODS

=head2 render( $view, [ \%context, \%use_layout ] )

Implements the C<render()> method, as defined and required by L<Leyland::View>.

=cut

sub render {
	my ($self, $view, $context, $use_layout) = @_;

	$use_layout = 1 unless defined $use_layout;

	return $self->engine->render($view, $context, $use_layout);
}

=head1 INTERNAL METHODS

The following methods are only to be used internally.

=head2 _init_engine()

=cut

sub _init_engine {
	return Tenjin->new({ path => ['views'], postfix => '.html', layout => 'layouts/main.html' });
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::View::Tenjin

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

Copyright 2010-2011 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

__PACKAGE__->meta->make_immutable;
