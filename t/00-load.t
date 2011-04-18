#!perl -T

use Test::More tests => 2;

BEGIN {
	use_ok( 'Leyland' ) || print "Leyland bail out!\n";
	use_ok( 'Leyland::Cmd' ) || print "Leyland::Cmd bail out!\n";
}

diag( "Testing Leyland $Leyland::VERSION, Perl $], $^X" );
