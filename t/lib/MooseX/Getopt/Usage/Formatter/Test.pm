package MooseX::Getopt::Usage::Formatter::Test;

use strict;
use warnings;

use base qw(Test::Class);
use Test::More;
use Test::Exception;
use MooseX::Getopt::Usage::Formatter;

sub constructor : Test(2) {
    my $self = shift;

    my $tclass = "MooseX::Getopt::Usage::Formatter";
    throws_ok { $tclass->new() } qr/Attribute \(getopt_class\) is required/,
        "No args failes (need getopt_class)";

    lives_ok {
        $tclass->new( getopt_class => 'MooseX::Getopt::Usage::Formatter::Test' )
    } "Only getopt_class";
}

1;
