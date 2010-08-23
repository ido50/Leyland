package Leyland::Localizer::Wolowitz;

use Moose;
use namespace::autoclean;
use lib '/home/ido/git/Wolowitz/lib';
use Wolowitz;
use Carp;

with 'Leyland::Localizer';

sub init_localizer {
	my ($self, $config) = @_;

	my %args = (
		app => $config->{app},
		db_name => $config->{localizer}->{db_name},
	);
	
	$args{host} = $config->{localizer}->{host} || 'localhost';
	$args{port} = $config->{localizer}->{port} || 27017;

	croak "Your app's configuration must have an app name (config key 'app') and the name of the Wolowitz database to use (config key 'db_name' under 'localizer')."
		unless $args{app} && $args{db_name};

	my $w = Wolowitz->new(%args);

	return $w;
}

sub loc {
	my $self = shift;

	return $self->localizer->loc(@_);
}

__PACKAGE__->meta->make_immutable;
