package Leyland::Exception;

use Moose;
use namespace::autoclean;

with 'Throwable';

my $CODES = {
	200 => ['OK', 'Standard response for successful HTTP requests.'],
	201 => ['Created', 'The request has been fulfilled and resulted in a new resource being created.'],
	202 => ['Accepted', 'The request has been accepted for processing, but the processing has not been completed.'],
	204 => ['No Content', 'The server successfully processed the request, but is not returning any content.'],
	
	300 => ['Multiple Choices', 'Indicates multiple options for the resource that the client may follow.'],
	301 => ['Moved Permanently', 'This and all future requests should be directed to the given URI.'],
	302 => ['Found', 'Temporary redirect.'],
	303 => ['See Other', 'The response to the request can be found under another URI using a GET method.'],
	304 => ['Not Modified', 'Indicates the resource has not been modified since last requested.'],
	307 => ['Temporary Redirect', 'The request should be repeated with another URI, but future requests can still use the original URI.'],
	
	400 => ['Bad Request', 'The request cannot be fulfilled due to bad syntax.'],
	401 => ['Unauthorized', 'Similar to 403 Forbidden, but specifically for use when authentication is possible but has failed or not yet been provided.'],
	403 => ['Forbidden', 'The request was a legal request, but the server is refusing to respond to it.'],
	404 => ['Not Found', 'The requested resource could not be found but may be available again in the future.'],
	405 => ['Method Not Allowed', 'A request was made of a resource using a request method not supported by that resource.'],
	406 => ['Not Acceptable', 'The requested resource is only capable of generating content not acceptable according to the Accept headers sent in the request.'],
	408 => ['Request Timeout', 'The server timed out waiting for the request.'],
	409 => ['Conflict', 'Indicates that the request could not be processed because of conflict in the request, such as an edit conflict.'],
	410 => ['Gone', 'Indicates that the resource requested is no longer available and will not be available again.'],
	411 => ['Length Required', 'The request did not specify the length of its content, which is required by the requested resource.'],
	412 => ['Precondition Failed', 'The server does not meet one of the preconditions that the requester put on the request.'],
	413 => ['Request Entity Too Large', 'The request is larger than the server is willing or able to process.'],
	414 => ['Request-URI Too Long', 'The URI provided was too long for the server to process.'],
	415 => ['Unsupported Media Type', 'The request entity has a media type which the server or resource does not support.'],
	417 => ['Expectation Failed', 'The server cannot meet the requirements of the Expect request-header field.'],
	
	500 => ['Internal Server Error', 'A generic error message, given when no more specific message is suitable.'],
	501 => ['Not Implemented', 'The server either does not recognise the request method, or it lacks the ability to fulfill the request.'],
	503 => ['Service Unavailable', 'The server is currently unavailable (because it is overloaded or down for maintenance).'],
};

has 'code' => (is => 'ro', isa => 'Int', required => 1);

has 'error' => (is => 'ro', predicate => 'has_error', writer => '_set_error');

has 'mimes' => (is => 'ro', isa => 'HashRef', predicate => 'has_mimes');

sub BUILD {
	my $self = shift;

	unless ($self->has_error) {
		$self->_set_error({
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
	$CODES->{$_[0]->code}->[0] || 'Internal Server Error';
}

sub description {
	$CODES->{$_[0]->code}->[1] || 'Generic HTTP exception';
}

__PACKAGE__->meta->make_immutable;
