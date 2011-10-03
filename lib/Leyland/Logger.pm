package Leyland::Logger;

# ABSTARCT: Logging facilities for Leyland applications

use Moose;
use namespace::autoclean;

has 'logger' => (
	is => 'ro',
	isa => 'CodeRef',
	default => sub {
		sub {
			my $args = shift;

			# should print to STDERR if level is appropriate
			print STDOUT '['.$args->{level}.'] '.$args->{message}, "\n";
		}
	}
);

has 'supports' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub {
		{
			identifier => 0,
		}
	}
);

my $meta = __PACKAGE__->meta;

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
	foreach my $method (@$_) {
		$meta->add_method($method => sub {
			my $self = shift;

			my $message = {
				level => $level,
				message => $_[0],
			};
			if ($_[1]) {
				$message->{data} = $_[1];
			}

			$self->logger->($message);
		});
	}
}

sub identifier {
	my ($self, $key, $value) = @_;

	return unless $self->supports->{identifier};

	$self->logger->({ identifier => $key, value => $value });
}

sub id {
	shift->supports->{log_id};
}

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

Copyright 2010-2011 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

$meta->make_immutable;
1;
