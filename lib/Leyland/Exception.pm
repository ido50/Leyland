package Leyland::Exception;

use Moose;
use namespace::autoclean;

with 'Throwable';

has 'code' => (is => 'ro', isa => 'Int', required => 1);

has 'error' => (is => 'ro', predicate => 'has_error', writer => '_set_error');

has 'mimes' => (is => 'ro', isa => 'HashRef', predicate => 'has_mimes');

has 'use_layout' => (is => 'ro', isa => 'Bool', default => 1);

sub BUILD {
	my $self = shift;

	unless ($self->has_error) {
		$self->_set_error({
			code => $self->code,
			error => $self->name,
			description => $self->description,
		});
	}
}

sub has_mime {
	my ($self, $mime) = @_;

	return unless $self->has_mimes;

	return exists $self->mimes->{$mime};
}

sub mime {
	my ($self, $mime) = @_;

	return unless $self->has_mime($mime);

	return $self->mimes->{$mime};
}

sub name {
	$Leyland::CODES->{$_[0]->code}->[0] || 'Internal Server Error';
}

sub description {
	$Leyland::CODES->{$_[0]->code}->[1] || 'Generic HTTP exception';
}

__PACKAGE__->meta->make_immutable;
