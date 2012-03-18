package MooseX::Getopt::Usage::Role::Man;

use 5.010;
our $VERSION = '0.06';

use Moose::Role;
use Pod::Usage;
use Pod::Find qw(pod_where);
use File::Slurp qw(slurp);

has man => (
    is            => 'rw',
    isa           => 'Bool',
    traits        => ['Getopt'],
    cmd_flag      => 'man',
    documentation => "Display man page"
);

my $USAGE_FORMAT = <<EOFORMAT;

=head1 SYNOPSIS

    %c [options]
EOFORMAT

sub getopt_usage_man {
    my $self  = shift;
    my $class = blessed $self || $self;

    #my @attrs = sort { $attr_sort->($a, $b) } $self->_compute_getopt_attrs;
    my @attrs = $self->_compute_getopt_attrs;
    my $usage = $self->getopt_usage(
        headings  => 0,
        use_color => 0,
        format    => $USAGE_FORMAT,
    );
    $usage .= "\n=head1 OPTIONS\n\n";
    $usage .= "=over 4\n\n";
    foreach my $attr (@attrs) {
        my $label = $self->_getopt_usage_attr_label($attr);
        $usage .= "=item B<$label>\n\n";
        $usage .= $attr->documentation."\n\n";
    }
    $usage .= "=back\n\n";

    my $podfile = pod_where( {-inc => 1}, $class );
    my $pod = slurp $podfile;
    $pod =~ s/(^=head1 DESCRIPTION.*?$)/$usage\n$1\n/ms;
    open my $fh, "<", \$pod or die;
    pod2usage( -verbose => 2, -input => $fh );
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

