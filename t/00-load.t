#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Otto' ) || print "Bail out!
";
}

diag( "Testing Otto $Otto::VERSION, Perl $], $^X" );
