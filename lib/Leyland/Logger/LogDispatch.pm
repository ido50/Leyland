package Leyland::Logger::LogDispatch;

use Moose;
use namespace::autoclean;
use Log::Dispatch;

has 'obj' => (is => 'ro', isa => 'Log::Dispatch', writer => '_set_obj');

with 'Leyland::Logger';

sub init {
	my ($self, $opts) = @_;

	$self->_set_obj(Log::Dispatch->new(%$opts));
}

sub log {
	my ($self, $msg) = @_;

	$self->obj->log(level => $msg->{level}, message => $msg->{message});
}

__PACKAGE__->meta->make_immutable;
