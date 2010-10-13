package Leyland::Logger;

use Moose;
use namespace::autoclean;

has 'logger' => (is => 'ro', isa => 'CodeRef', default => sub { \&_default_logger });

has 'exec' => (is => 'ro', isa => 'CodeRef', writer => '_set_exec', predicate => 'has_exec', clearer => 'clear_exec');

has 'args' => (is => 'rw', isa => 'ArrayRef', writer => '_set_args', predicate => 'has_args', clearer => 'clear_args');

=head1 METHODS

=head2 debug( $msg )

Generates a debug message.

=cut

sub debug {
	$_[0]->logger->({ level => 'debug', message => $_[1] });
}

=head2 info( $msg )

Generates an info message.

=cut

sub info {
	$_[0]->logger->({ level => 'info', message => $_[1] });
}

=head2 warn( $msg )

Generates a warning message.

=cut

sub warn {
	$_[0]->logger->({ level => 'warn', message => $_[1] });
}

=head2 error( $msg )

Generates an error message.

=cut

sub error {
	$_[0]->logger->({ level => 'error', message => $_[1] });
}

sub _default_logger {
	my @lt = localtime;
	$lt[5] += 1900; # fix year

	foreach (0 .. 4) {
		$lt[$_] = '0'.$lt[$_] if $lt[$_] < 10;
	}

	my $ymd = join('-', $lt[5], $lt[4], $lt[3]);
	my $hms = join(':', $lt[2], $lt[1], $lt[0]);

	print STDERR $ymd, ' ', $hms, ' [', uc($_[0]->{level}), '] ', $_[0]->{message}, "\n";
}

sub set_exec {
	my ($self, $sub) = (shift, shift);

	$self->_set_exec($sub);
	$self->_set_args(\@_) if scalar @_;
}

around qr/^(debug|info|warn|error)$/ => sub {
	my ($orig, $self, $msg) = @_;

	if ($self->has_exec) {
		my @args = ($msg);
		unshift(@args, @{$self->args}) if $self->has_args;
		$msg = $self->exec->(@args);
		chomp($msg);
	}

	return $self->$orig($msg);
};

__PACKAGE__->meta->make_immutable;
