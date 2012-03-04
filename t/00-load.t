#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'MooseX::Getopt::Usage' ) || print "Bail out!
";
}

diag( "Testing MooseX::Getopt::Usage $MooseX::Getopt::Usage::VERSION, Perl $], $^X" );
