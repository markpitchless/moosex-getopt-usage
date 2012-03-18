package MooseX::Getopt::Usage::Role::Man;

our $VERSION = '0.06';

use Moose::Role;
use Pod::Usage;

has man => (
    is            => 'rw',
    isa           => 'Bool',
    traits        => ['Getopt'],
    cmd_flag      => 'man',
    documentation => "Display man page"
);

sub getopt_usage_man {
    my $self  = shift;
    my $class = blessed $self || $self;

    (my $classfile = "$class.pm") =~ s/::/\//g;
    my $podfile = $INC{$classfile};
    pod2usage( -verbose => 2, -input => $podfile )
}

no Moose::Role;

1;
__END__

=pod

=head1 NAME

MooseX::Getopt::Usage::Role::Man - Add man page (generated from POD) option.

=head1 SYNOPSIS

 with 'MooseX::Getopt::Usage'
 with 'MooseX::Getopt::Usage::Role::Man';

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 man

The --man option on the command line. If true after class construction
program will exit displaying the man generated from the POD.

=head1 METHODS

=head2 getopt_usage_man

Generate the man page and exit, via L<Pod::Usage>.

=head1 SEE ALSO

L<MooseX::Getopt::Usage>, L<Pod::Usage>, L<Moose>, L<perl>.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.
See L<MooseX::Getopt::Usage/BUGS> for details of how to report bugs.

=head1 AUTHOR


=head1 COPYRIGHT

See L<MooseX::Getopt::Usage/COPYRIGHT>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

