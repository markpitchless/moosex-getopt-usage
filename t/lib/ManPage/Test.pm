package ManPage::Test;

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
    use_ok('ManPage');
}

sub manpage : Test(2) {
    my $self = shift;

    my $testme = ManPage->new();
    ok( $testme, "Construct ManPage" ) or die "No object to test with!";

    my $out_ok = slurp("$Bin/manpage.getopt_usage.ok");
    my $out = $testme->getopt_usage;
    eq_or_diff $out, $out_ok, "ManPage";

    # TODO: Current man page implimentation doesn't support getting the man
    # page back as a string as we hand off to Pod::Usage.
}

sub manpage_cmd_line : Test(8) {
    my $self = shift;

    my $stdout_ok = slurp("$Bin/manpage.man.ok");
    my $stderr_ok = "";
    foreach my $flag (qw/--man/) {
        my $cmd = "manpage $flag";
        my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
        eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
        eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
    }
    
    $stdout_ok = slurp "$Bin/manpage.usage.ok";
    $stderr_ok = "";
    foreach my $flag (qw/-? --help --usage/) {
        my $cmd = "manpage $flag";
        my ($stdout, $stderr) = capture { system("$TBin/$cmd") };
        eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
        eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
    }
}

1;
