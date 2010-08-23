package Leyland::Localizer;

use Moose::Role;
use namespace::autoclean;

has 'localizer' => (is => 'ro', isa => 'Object', writer => '_set_localizer');

requires 'init_localizer';

requires 'loc';

sub init {
	my ($class, $config) = @_;

	my $self = $class->new();
	$self->_set_localizer($self->init_localizer($config));

	return $self;
}

1;
