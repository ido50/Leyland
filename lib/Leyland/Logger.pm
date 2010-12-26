package Leyland::Logger;

# ABSTARCT: Logging facilities for Leyland applications

use Moose::Role;
use namespace::autoclean;

=head1 NAME

Leyland::Logger - Logging facilities for Leyland applications

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 CLASS METHODS

=head1 OBJECT METHODS

=cut

requires 'init';

requires 'log';

has 'exec' => (is => 'ro', isa => 'CodeRef', writer => '_set_exec', predicate => 'has_exec', clearer => 'clear_exec');

has 'args' => (is => 'rw', isa => 'ArrayRef', writer => '_set_args', predicate => 'has_args', clearer => 'clear_args');

=head1 METHODS

=head2 debug( $msg )

Generates a debug message.

=cut

sub debug {
	$_[0]->log({ level => 'debug', message => $_[1] });
}

=head2 info( $msg )

Generates an info message.

=cut

sub info {
	$_[0]->log({ level => 'info', message => $_[1] });
}

=head2 warn( $msg )

Generates a warning message.

=cut

sub warn {
	$_[0]->log({ level => 'warn', message => $_[1] });
}

=head2 error( $msg )

Generates an error message.

=cut

sub error {
	$_[0]->log({ level => 'error', message => $_[1] });
}

sub set_exec {
	my ($self, $sub) = (shift, shift);

	$self->_set_exec($sub);
	$self->_set_args(\@_) if scalar @_;
}

around [qw/debug info warn error/] => sub {
	my ($orig, $self, $msg) = @_;

	if ($self->has_exec) {
		my @args = ($msg);
		unshift(@args, @{$self->args}) if $self->has_args;
		$msg = $self->exec->(@args);
		chomp($msg);
	}

	return $self->$orig($msg);
};

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

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
