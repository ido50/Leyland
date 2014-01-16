package LeylandTestApp::Controller::Articles;

use Moo;
use Leyland::Parser;
use namespace::clean;

with 'Leyland::Controller';

prefix { '/articles' }

get '^/(\w+)$' {
	my $id = shift;

	return { get => $id };
}

del '^/(\w+)$' {
	my $id = shift;

	return { del => $id };
}

1;
