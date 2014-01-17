package LeylandTestApp;

use Moo;

extends 'Leyland';

sub setup {
	return {
		views => ['Tenjin'],
		default_mime => 'application/json'
	};
}

1;
