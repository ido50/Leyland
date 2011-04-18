package Leyland::Cmd::Command;

# ABSTRACT: Base class for 'leyland' command line application commands

use strict;
use warnings;
use App::Cmd::Setup -command;

=head1 NAME

Leyland::Cmd::Command - Base class for 'leyland' command line application commands

=head1 CLASS METHODS

=head2 opt_spec( $app )

=cut

sub opt_spec {
	my ($class, $app) = @_;

	return (
		[ 'help' => "This usage screen" ],
		$class->options($app),
	)
}

=head2 validate_args( $opt, $args )

=cut

sub validate_args {
	my ($self, $opt, $args) = @_;

	die $self->_usage_text if $opt->{help};
	$self->validate( $opt, $args );
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Cmd::Command

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

1;
