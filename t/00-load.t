#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Leyland' ) || print "Bail out!
";
}

diag( "Testing Leyland $Leyland::VERSION, Perl $], $^X" );
