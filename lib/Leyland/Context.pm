package Leyland::Context;

use Moose;
use namespace::autoclean;
use Plack::Request;

has 'env' => (is => 'ro', isa => 'HashRef', required => 1);

has 'req' => (is => 'ro', isa => 'Plack::Request', lazy_build => 1);

sub _build_req {
	my $self = shift;

	Plack::Request->new($self->env);
}

__PACKAGE__->meta->make_immutable;
