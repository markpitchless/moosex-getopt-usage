package ManPage::Test;

use 5.010;
use strict;
use warnings;

use base qw(Test::Class);
use Test::More;
use Capture::Tiny qw(:all);
use Test::Differences;
use File::Slurp qw(slurp);

use FindBin qw($Bin);
our $TBin = "$Bin/bin";

sub startup : Test(startup => 1) {
    use_ok('ManPage');
}

# TODO: Current man page implimentation doesn't support getting the man page
# back as a string as we hand off to Pod::Usage.
#sub manpage : Test(2) {
#    my $self = shift;
#
#    my $testme = ManPage->new();
#    ok( $testme, "Construct ManPage" ) or die "No object to test with!";
#
#    my $out_ok = <<EOSTDOUT;
#Usage:
#    manpage.t [OPTIONS]
#Options:
#    --help -? --usage - Bool. Display the usage message and exit
#    --verbose         - Bool. Say lots about what we do
#    --greet           - Str. Default=World. Who to say hello to.
#    --language        - Str. Default=en. Language to greet in.
#EOSTDOUT
#    my $out = $testme->getopt_usage;
#    eq_or_diff $out, $out_ok, "ManPage";
#}

sub manpage_cmd_line : Test(2) {
    my $self = shift;

    my $stdout_ok = slurp("$Bin/manpage.ok");
    my $stderr_ok = "";
    foreach my $flag (qw/--man/) {
        my $cmd = "$TBin/manpage $flag";
        my ($stdout, $stderr) = capture { system($cmd) };
        eq_or_diff $stdout, $stdout_ok, "$cmd STDOUT";
        eq_or_diff $stderr, $stderr_ok, "$cmd STDERR";
    }
}

1;
