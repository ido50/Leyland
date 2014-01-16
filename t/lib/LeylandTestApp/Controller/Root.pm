package LeylandTestApp::Controller::Root;

use Moo;
use Leyland::Parser;
use namespace::clean;

with 'Leyland::Controller';

prefix { '' }

get '^/$' returns 'text/plain' {
	return "Index";
}

get '^/exception$' returns 'application/json' {
	$c->exception({ code => 400, error => 'This is a simple text exception' });
}

1;
