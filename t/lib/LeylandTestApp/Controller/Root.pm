package LeylandTestApp::Controller::Root;

use Moo;
use Leyland::Parser;

with 'Leyland::Controller';

prefix { '' }

get '^/$' accepts 'application/json' returns 'application/json' {
	return { success => 1 };
}

1;
