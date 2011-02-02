package Leyland::Exception;

# ABSTRACT: Throwable class for Leyland application exceptions

use Moose;
use namespace::autoclean;

=head1 NAME

Leyland::Exception - Throwable class for Leyland application exceptions

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 CLASS METHODS

=head1 OBJECT METHODS

=cut

with 'Throwable';

has 'code' => (is => 'ro', isa => 'Int', required => 1);

has 'error' => (is => 'ro', isa => 'Str', predicate => 'has_error', writer => '_set_error');

has 'location' => (is => 'ro', isa => 'Str', predicate => 'has_location');

has 'mimes' => (is => 'ro', isa => 'HashRef', predicate => 'has_mimes');

has 'use_layout' => (is => 'ro', isa => 'Bool', default => 1);

sub BUILD {
	my $self = shift;

	$self->_set_error($self->code . ' ' . $self->name) unless $self->has_error;
}

sub has_mime {
	my ($self, $mime) = @_;

	return unless $self->has_mimes;

	return exists $self->mimes->{$mime};
}

sub mime {
	my ($self, $mime) = @_;

	return unless $self->has_mime($mime);

	return $self->mimes->{$mime};
}

sub name {
	$Leyland::CODES->{$_[0]->code}->[0] || 'Internal Server Error';
}

sub description {
	$Leyland::CODES->{$_[0]->code}->[1] || 'Generic HTTP exception';
}

sub hash {
	my $self = shift;

	return {
		error => $self->code . ' ' . $self->name,
		message => $self->error,
		description => $self->description,
	};
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Exception

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
