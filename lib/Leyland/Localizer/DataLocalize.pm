package Leyland::Localizer::DataLocalize;

use Moose;
use namespace::autoclean;
use Data::Localize;
use Carp;

with 'Leyland::Localizer';

sub init_localizer {
	my ($self, $config) = @_;

	my $loc = Data::Localize->new();

	foreach (@{$config->{localizer}->{localizers}}) {
		$loc->add_localizer(%$_);
	}

	my @langs = exists $config->{localizer}->{langs} ? @{$config->{localizer}->{langs}} : ();

	$loc->set_languages(@langs);

	return $loc;
}

sub loc {
	shift->localizer->localize(@_);
}

__PACKAGE__->meta->make_immutable;
