package Basic::Test;

use 5.010;
use strict;
use warnings;

use base qw(Test::Class);
use Test::More;
use Capture::Tiny qw(:all);
use Test::Differences;

use FindBin qw($Bin);
our $TBin = "$Bin/bin";

sub startup : Test(startup => 1) {
    use_ok('Basic');
}

sub basic : Test(2) {
    my $self = shift;

    my $testme = Basic->new();
    ok( $testme, "Construct Basic" ) or die "No object to test with!";

    my $out_ok = <<EOSTDOUT;
Usage:
    basic.t [OPTIONS]
Options:
    --help -? --usage - Bool. Display the usage message and exit
    --verbose         - Bool. Say lots about what we do
    --greet           - Str. Default=World. Who to say hello to.
    --language        - Str. Default=en. Language to greet in.
EOSTDOUT
    my $out = $testme->getopt_usage;
    eq_or_diff $out, $out_ok, "Basic";
}

1;
