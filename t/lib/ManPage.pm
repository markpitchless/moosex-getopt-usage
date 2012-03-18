package ManPage;
use strict;
use warnings;

use Moose;
with 'MooseX::Getopt::Usage';

=pod

=head1 NAME

manpage - Using MooseX::Getopt::Usage and Pod::Usage

=head1 SYNOPSIS

manpage [options] [file ...]

Options:
  -help	       brief help message
  -man	       full documentation

=head1 OPTIONS

=over 4

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

1;
