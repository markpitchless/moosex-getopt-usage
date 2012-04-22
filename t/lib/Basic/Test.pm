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

sub cmd_stdout_like {
    my $cmd  = shift;
    my $re   = shift;
    my $tname = shift || "$cmd; stdout like $re";

    my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
    like $stdout, $re, $tname;
}

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
    eq_or_diff $out, $out_ok, "Basic->getopt_usage";
}

# Does the error message make it to the message
sub err_message : Test(1) {
    my $self = shift;

    my $testme = Basic->new() or die "No object to test with!";
    my $out = $testme->getopt_usage( err => "Error: Hello World" );
    like $out, qr/^Error: Hello World\n/, "Basic->getopt_usage( err => ... )";
}

# Are we trapping command line errors properly. ie in new_with_options
sub cmd_line_errors : Tests(2) {
    my $self = shift;

    cmd_stdout_like 'basic --notanoption',
        qr/^Unknown option: notanoption\nUsage/;
    cmd_stdout_like 'basic --verbose=2',
        qr/^Option verbose does not take an argument\nUsage/;

    # TODO : Test all the error traps and test status code.
}


1;
