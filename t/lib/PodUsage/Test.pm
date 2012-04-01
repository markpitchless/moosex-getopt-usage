package PodUsage::Test;

use 5.010;
use strict;
use warnings;

use base qw(Test::Class);
use Test::More;
use Capture::Tiny qw(:all);
use Test::Differences;
use File::Slurp qw(slurp);
use File::Basename;

use FindBin qw($Bin);
our $TBin = "$Bin/bin";

sub startup : Test(startup => 1) {
    use_ok('PodUsage');
}

sub podusage_cmd_line : Test(8) {
    my $self = shift;

    my $stdout_ok = slurp("$Bin/podusage.man.ok");
    my $stderr_ok = "";
    foreach my $flag (qw/--man/) {
        my $cmd = "podusage $flag";
        my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
        eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
        eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
    }
    
    $stdout_ok = slurp "$Bin/podusage.usage.ok";
    $stderr_ok = "";
    foreach my $flag (qw/-? --help --usage/) {
        my $cmd = "podusage $flag";
        my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
        eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
        eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
    }
}

1;
