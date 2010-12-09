package Leyland::View::Tenjin;

# ABSTRACT: Tenjin view class for Leyland

use Moose;
use namespace::autoclean;
use Tenjin;

=head1 NAME

Leyland::View::Tenjin - Tenjin view class for Leyland

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CLASS METHODS

=head1 OBJECT ATTRIBUTES

=head1 OBJECT METHODS

=cut

with 'Leyland::View';

has 'engine' => (is => 'ro', isa => 'Tenjin', builder => '_init_engine');

sub _init_engine {
	return Tenjin->new({ path => ['views'], postfix => '.html', layout => 'layouts/main.html' });
}

sub render {
	my ($self, $view, $context, $use_layout) = @_;

	$use_layout = 1 unless defined $use_layout;

	return $self->engine->render($view, $context, $use_layout);
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

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

__PACKAGE__->meta->make_immutable;
