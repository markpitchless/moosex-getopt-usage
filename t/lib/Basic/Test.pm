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

sub basic_cmd_line : Test(6) {
    my $self = shift;

    my $stdout_ok = <<EOSTDOUT;
Usage:
    basic [OPTIONS]
Options:
    --help -? --usage - Bool. Display the usage message and exit
    --verbose         - Bool. Say lots about what we do
    --greet           - Str. Default=World. Who to say hello to.
    --language        - Str. Default=en. Language to greet in.
EOSTDOUT
    my $stderr_ok = "";
    foreach my $flag (qw/-? --help --usage/) {
        my $cmd = "$TBin/basic $flag";
        my ($stdout, $stderr) = capture { system($cmd) };
        eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
        eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
    }
}

1;
