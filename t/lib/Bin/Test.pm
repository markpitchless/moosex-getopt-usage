package Bin::Test;

#
# Test all the exes in the TBin. Running with --help and --man options
# comparing output to files in t/bin.ok/
#

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

# Generate test methods for all the exes in TBin
opendir(my $dh, $TBin) || die "Can't open $TBin: $!";
my @cmds = grep { -f "$TBin/$_" && -x "$TBin/$_" } readdir($dh);
closedir($dh);
foreach my $cmd (@cmds) {
    no strict 'refs';
    my $meth = __PACKAGE__ . "::$cmd";
    *{$meth} = sub {
        my $self = shift;
        $self->cmd_line_ok($cmd);
    };
    __PACKAGE__->add_testinfo($cmd, test => 8);
}

sub cmd_line_ok {
    my $self = shift;
    my $cmd  = shift;

    my $ok_file = "$Bin/bin.ok/$cmd.usage.ok";
    if (-f $ok_file) {
        my $stdout_ok = slurp($ok_file);
        my $stderr_ok = "";
        foreach my $flag (qw/-? --help --usage/) {
            my $cmd = "$cmd $flag";
            my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
            eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
            eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
        }
    }
    
    $ok_file = "$Bin/bin.ok/$cmd.man.ok";
    if (-f $ok_file) {
        my $stdout_ok = slurp($ok_file);
        my $stderr_ok = "";
        foreach my $flag (qw/--man/) {
            my $cmd = "$cmd $flag";
            my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
            eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
            eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
        }
    }
}

1;
