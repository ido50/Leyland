package Leyland::Logger;

use Moose::Role;
use namespace::autoclean;

has 'logger' => (is => 'ro', isa => 'Object', writer => '_set_logger');

requires 'init_logger';

requires 'new_request_log';

sub init {
my ($class, $config) = @_;

my $self = $class->new();
$self->_set_logger($self->init_logger($config));

return $self;
}

1;

