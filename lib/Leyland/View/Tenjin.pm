package Leyland::View::Tenjin;

use Moose;
use namespace::autoclean;
use Tenjin;

with 'Leyland::View';

has 'name' => (is => 'ro', isa => 'Str', default => 'Tenjin');

has 'engine' => (is => 'ro', isa => 'Tenjin', builder => '_init_engine');

sub _init_engine {
	return Tenjin->new({ path => 'views', postfix => '.html' });
}

sub render {
	my ($self, $view, $context) = @_;

	return $self->engine->render($view, $context);
}

__PACKAGE__->meta->make_immutable;
