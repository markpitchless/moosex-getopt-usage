package ManPage;
use strict;
use warnings;

use Moose;
with 'MooseX::Getopt::Usage';
with 'MooseX::Getopt::Usage::Role::Man';

=pod

=head1 NAME

manpage - Using MooseX::Getopt::Usage and Pod::Usage

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

1;
