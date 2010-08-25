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
	my ($self, $view, $context, $use_layout) = @_;

	$use_layout = 1 unless defined $use_layout;

	return $self->engine->render($view, $context, $use_layout);
}

__PACKAGE__->meta->make_immutable;
