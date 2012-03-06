package Basic::Test;

use 5.010;
use strict;
use warnings;

use base qw(Test::Class);
use Test::More;
use Capture::Tiny qw(:all);
use Test::Differences;

sub startup : Test(startup => 1) {
    use_ok('Basic');
}

sub defaults : Test(3) {
    my $self = shift;

    my $testme = Basic->new();
    ok( $testme, "Construct Basic" ) or die "No object to test with!";

    my $stdout_ok = <<EOSTDOUT;
Usage:
    basic.t [OPTIONS]
Options:
    --help -? --usage - Bool. Display the usage message and exit
    --verbose         - Bool. Say lots about what we do
    --greet           - Str. Default=World. Who to say hello to.
    --language        - Str. Default=en. Language to greet in.
EOSTDOUT
    my $stderr_ok = "";
    my ($stdout, $stderr) = capture { $testme->getopt_usage };
    eq_or_diff $stdout, $stdout_ok, "Basic STDOUT";
    eq_or_diff $stderr, $stderr_ok, "Basic STDERR";
}

1;
