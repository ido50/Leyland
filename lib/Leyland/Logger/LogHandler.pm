package Leyland::Logger::LogHandler;

use Moose;
use namespace::autoclean;
use Log::Handler;

has 'obj' => (is => 'ro', isa => 'Log::Handler', writer => '_set_obj');

with 'Leyland::Logger';

sub init {
	my ($self, $opts) = @_;

	$self->_set_obj(Log::Handler->new(@{$opts->{outputs}}));
}

sub log {
	my ($self, $msg) = @_;

	my $level = $msg->{level};
	my $message = $msg->{message};

	$self->obj->$level($message);
}

__PACKAGE__->meta->make_immutable;
