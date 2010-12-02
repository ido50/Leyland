package Leyland::Localizer;

use Moose;
use namespace::autoclean;
use Wolowitz;

has 'path' => (is => 'ro', isa => 'Str', required => 1);

has 'w' => (is => 'ro', isa => 'Wolowitz', writer => '_set_w');

sub BUILD {
	$_[0]->_set_w(Wolowitz->new($_[0]->path));
}

sub loc {
	shift->w->loc(@_);
}

__PACKAGE__->meta->make_immutable;
