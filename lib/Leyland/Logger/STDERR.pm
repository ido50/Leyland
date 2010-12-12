package Leyland::Logger::STDERR;

use Moose;
use namespace::autoclean;

with 'Leyland::Logger';

sub init {
	1;
}

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

__PACKAGE__->meta->make_immutable;
