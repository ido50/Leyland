package Leyland::View::Tenjin;

use Moose;
use namespace::autoclean;
use Tenjin;

with 'Leyland::View';

has 'engine' => (is => 'ro', isa => 'Tenjin', builder => '_init_engine');

sub _init_engine {
	return Tenjin->new({ path => ['views'], postfix => '.html', layout => 'layouts/main.html' });
}

sub render {
	my ($self, $view, $context) = @_;

	return $self->engine->render($view, $context);
}

__PACKAGE__->meta->make_immutable;
