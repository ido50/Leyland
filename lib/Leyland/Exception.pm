package Leyland::Exception;

use Moose;
use namespace::autoclean;

with 'Throwable';

has 'code' => (is => 'ro', isa => 'Int', required => 1);

has 'error' => (is => 'ro', isa => 'Str', predicate => 'has_error', writer => '_set_error');

has 'mimes' => (is => 'ro', isa => 'HashRef', predicate => 'has_mimes');

has 'use_layout' => (is => 'ro', isa => 'Bool', default => 1);

sub BUILD {
	my $self = shift;

	$self->_set_error($self->code . ' ' . $self->name) unless $self->has_error;
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

sub hash {
	my $self = shift;

	return {
		error => $self->code . ' ' . $self->name,
		message => $self->error,
		description => $self->description,
	};
}

__PACKAGE__->meta->make_immutable;
