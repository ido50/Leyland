#!/usr/bin/perl -w

BEGIN {
	$ENV{PLACK_ENV} = 'testing';
}

use lib 'lib', 't/lib';
use strict;
use warnings;
use HTTP::Request::Common qw/GET POST PUT DELETE/;
use Plack::Test;
use LeylandTestApp;
use Test::More;

my $app = LeylandTestApp->new(config => { app => 'LeylandTestApp', default_mime => 'application/json' })->to_app;
my $test = Plack::Test->create($app);

# test GET on the index route, which should return a plain text
my $res = $test->request(GET '/');
is($res->content, 'Index', 'GET index route ok');

# test GET on an article, which should return a JSON with the name of the article
$res = $test->request(GET '/articles/some_id');
is($res->content, '{"get":"some_id"}', 'GET article route ok');

# test DELETE on an article, which should return a JSON with the name of the article
$res = $test->request(DELETE '/articles/some_id');
is($res->content, '{"del":"some_id"}', 'DELETE article route ok');

# now lets tell Leyland we do not accept JSON and see what happens
$res = $test->request(GET '/articles/some_id', 'Accept' => 'text/plain');
is($res->code, 406, 'GET article when not accepting JSON returns 406');

# lets see if exceptions thrown by ourselves are properly returned
$res = $test->request(GET '/exception');
is($res->code, 400, 'GET exception returns a proper exception code');
is($res->content, 'This is a simple text exception', 'GET exception returns JSON for the exception text');

# lets see if the default mime is application/json and not text/html
$res = $test->request(GET '/default_mime');
is($res->content_type, 'application/json', 'Default mime is application/json, not text/html');

done_testing();
