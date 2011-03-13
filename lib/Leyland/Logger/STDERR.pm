package Leyland::Logger::STDERR;

use Moose;
use namespace::autoclean;

with 'Leyland::Logger';

=head1 NAME

Leyland::Logger::STDERR - Default logger, logs to STDERR

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

None.

=head1 CLASS METHODS

=head1 OBJECT METHODS

=head2 init()

Doesn't do anything in this module.

=cut

sub init { 1 }

=head2 log( { level => $level, message => $msg } )

Logs a message of a certain level.

=cut

sub log {
	my ($self, $msg) = @_;

	my @lt = localtime;
	$lt[5] += 1900; # fix year

	foreach (0 .. 4) {
		$lt[$_] = '0'.$lt[$_] if $lt[$_] < 10;
	}

	my $ymd = join('-', $lt[5], $lt[4], $lt[3]);
	my $hms = join(':', $lt[2], $lt[1], $lt[0]);

	print STDERR $ymd, ' ', $hms, ' [', uc($msg->{level}), '] ', $msg->{message}, "\n";
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Logger::STDERR

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
