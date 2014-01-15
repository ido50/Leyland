#!/usr/bin/perl -w
 
use lib './lib';
use strict;
use warnings;
use LeylandTestApp;

my $config = { app => 'LeylandTestApp' };

my $a = LeylandTestApp->new(config => $config);

my $app = sub {
	$a->handle(shift);
};
