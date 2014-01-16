package Leyland::Logger;

# ABSTARCT: Logging facilities for Leyland applications

use Moo;
use namespace::clean;

has 'logger' => (
	is => 'ro',
	isa => sub { die "logger must be a code reference" unless ref $_[0] && ref $_[0] eq 'CODE' },
	default => sub {
		sub {
			my $args = shift;

			# should print to STDERR if level is appropriate
			binmode STDOUT, ":encoding(utf8)";
			print STDOUT '| ['.$args->{level}.'] '.$args->{message}, "\n";
		}
	}
);

no strict 'refs';
foreach (
	['trace'],
	['debug'],
	['info', 'inform'],
	['notice'],
	['warning', 'warn'],
	['error', 'err'],
	['critical', 'crit', 'fatal'],
	['alert'],
	['emergency']
) {
	my $level = $_->[0];

	*{$level} = sub {
		my $self = shift;

		my $message = {
			level => $level,
			message => $_[0],
		};
		if ($_[1]) {
			$message->{data} = $_[1];
		}

		$self->logger->($message);
	};
}
use strict 'refs';

=head1 NAME

Leyland::Logger - Logging facilities for Leyland application

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Logger

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

Copyright 2010-2014 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
