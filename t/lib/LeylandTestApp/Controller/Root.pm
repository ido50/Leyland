package LeylandTestApp::Controller::Root;

use Moo;
use Leyland::Parser;
use namespace::clean;

with 'Leyland::Controller';

prefix { '' }

get '^/$' returns 'text/plain' {
	return "Index";
}

1;
