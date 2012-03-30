package MooseX::Getopt::Usage::Formatter;

our $VERSION = '0.01';

BEGIN {
    # Thanks to Hans Dieter Pearcey for this. See Getopt::Long::Descriptive.
    # Grab prog name before someone decides to change it.
    my $prog_name;
    sub _prog_name { @_ ? ($prog_name = shift) : $prog_name }
    _prog_name(File::Basename::basename($0));

    # Only use color when we are a terminal
    $ENV{ANSI_COLORS_DISABLED} = 1
        unless (-t STDOUT) && !exists $ENV{ANSI_COLORS_DISABLED};
}

use Moose;
#use MooseX::StrictConstructor;
use Term::ANSIColor;
use Term::ReadKey;
use Text::Wrap;
use Pod::Usage;
use Pod::Find qw(pod_where);
use File::Slurp qw(slurp);

has getopt_class => (
    is       => "rw",
    isa      => "ClassName",
    required => 1,
);

has colours => (
    is      => "rw",
    isa     => "HashRef",
    default => sub { {
        flag          => ['yellow'],
        heading       => ['bold'],
        command       => ['green'],
        type          => ['magenta'],
        default_value => ['cyan'],
        error         => ['red']
    } },
);

has headings => (
    is      => "rw",
    isa     => "Bool",
    default => 1,
);

has format => (
    is      => "rw",
    isa     => "Str",
    default => "Usage:\n    %c [OPTIONS]",
);

has attr_sort => (
    is      => "rw",
    isa     => "CodeRef",
    default => sub { sub {0} },
);

has use_color => (
    is      => "rw",
    isa     => "Bool",
);

has unexpand => (
    is      => "rw",
    isa     => "Int",
    default => 0,
);

has tabstop => (
    is      => "rw",
    isa     => "Int",
    default => 4,
);

sub usage {
    my $self = shift;
    my $args = { @_ };

    my $exit = $args->{exit};
    my $err  = $self->{err} || "";

    my $gclass    = $self->getopt_class;
    my $colours   = $self->colours;
    my $headings  = defined $args->{headings} ? $args->{headings} : $self->headings;
    my $format    = $args->{format}   || $self->format;
    my $attr_sort = $self->attr_sort;

    local $ENV{ANSI_COLORS_DISABLED} = 0
        if defined $args->{use_color} and not $args->{use_color};

    my @attrs = sort { $attr_sort->($a, $b) } $gclass->_compute_getopt_attrs;
    my $max_len = 0;
    my (@req_attrs, @opt_attrs);
    foreach (@attrs) {
        my $len  = length($self->_getopt_usage_attr_label($_));
        $max_len = $len if $len > $max_len;
        if ( $_->is_required && !$_->has_default && !$_->has_builder ) {
            push @req_attrs, $_;
        }
        else {
            push @opt_attrs, $_;
        }
    }

    my ($w) = GetTerminalSize;
    local $Text::Wrap::columns = $w -1 || 72;

    my $out = "";
    $out .= colored($colours->{error}, $err)."\n" if $err;
    $out .= $self->_getopt_usage_parse_format($format)."\n";
    $out .= colored($colours->{heading}, "Required:")."\n"
        if $headings && @req_attrs;
    $out .= $self->_getopt_usage_attr($_, max_len => $max_len )."\n"
        foreach @req_attrs;
    $out .= colored($colours->{heading}, "Options:")."\n"
        if $headings && @opt_attrs;
    $out .= $self->_getopt_usage_attr($_, max_len => $max_len )."\n"
        foreach @opt_attrs;

    if ( defined $exit ) {
        print $out;
        exit $exit;
    }
    return $out;
}

my $USAGE_FORMAT = <<EOFORMAT;

=head1 SYNOPSIS

    %c [options]
EOFORMAT

sub manpage {
    my $self   = shift;
    my $gclass = $self->getopt_class;

    #my @attrs = sort { $attr_sort->($a, $b) } $self->_compute_getopt_attrs;
    my @attrs = $gclass->_compute_getopt_attrs;
    my $usage = $self->usage(
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

    my $podfile = pod_where( {-inc => 1}, $gclass );
    my $pod = slurp $podfile;
    $pod =~ s/(^=head1 DESCRIPTION.*?$)/$usage\n$1\n/ms;
    open my $fh, "<", \$pod or die;
    pod2usage( -verbose => 2, -input => $fh );
}

sub _getopt_usage_parse_format {
    my $self    = shift;
    my $fmt     = shift or confess "No format";
    my $colours = $self->colours;

    $fmt =~ s/%c/colored $colours->{command}, _prog_name()/ieg;
    $fmt =~ s/%%/%/g;
    # TODO - Be good to have a include that generates a list of the opts
    #        %r - required  %a - all  %o - options
    $fmt =~ s/^(Usage:)/colored $colours->{heading}, "$1"/e;
    $self->_getopt_usage_colourise(\$fmt);
    return $fmt;
}


# Return the full label, including aliases and dashes, for the passed attribute
sub _getopt_usage_attr_label {
    my $self   = shift;
    my $attr   = shift || confess "No attr";
    my $gclass = $self->getopt_class;

    my ( $flag, @aliases ) = $gclass->_get_cmd_flags_for_attr($attr);
    my $label = join " ", map {
        length($_) == 1 ? "-$_" : "--$_"
    } ($flag, @aliases);
    return $label;
}

# Return the formated and coloured usage string for the passed attribute.
sub _getopt_usage_attr {
    my $self    = shift;
    my $attr    = shift or confess "No attr";
    my %args    = @_;
    my $max_len = $args{max_len} or confess "No max_len";
    my $colours = $self->colours;

    local $Text::Wrap::unexpand = $self->unexpand;
    local $Text::Wrap::tabstop  = $self->tabstop;

    my $label = $self->_getopt_usage_attr_label($attr);

    my $docs  = "";
    my $pad   = $max_len - length($label);
    my $def   = $attr->has_default ? $attr->default : "";
    (my $type = $attr->type_constraint) =~ s/(\w+::)*//g;
    $docs .= colored($colours->{type}, "$type. ") if $type;
    $docs .= colored($colours->{default_value}, "Default=$def").". "
        if $def && ! ref $def;
    $docs  .= $attr->documentation || "";

    my $col1 = "    $label";
    $col1 .= "".( " " x $pad );
    my $out = wrap($col1, (" " x ($max_len + 9)), " - $docs" );
    $self->_getopt_usage_colourise(\$out);
    return $out;
}

# Extra colourisation for the attributes usage string. Think syntax highlight.
sub _getopt_usage_colourise {
    my $self    = shift;
    my $out     = shift || "";
    my $colours = $self->colours;

    my $str = ref $out ? $out : \$out;
    $$str =~ s/(\s--?[\w?]+)/colored $colours->{flag}, "$1"/ge;
    return ref $out ? $out : $$str;
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;
__END__

=pod

=head1 NAME

MooseX::Getopt::Usage::Formatter - 

=head1 SYNOPSIS

 my $obj = MooseX::Getopt::Usage::Formatter->new();

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 getopt_class

=head2 colours

=head2 headings

=head2 format

=head2 attr_sort

=head2 use_color

=head2 unexpand

=head2 tabstop

=head1 METHODS

=head1 SEE ALSO

L<Moose>, L<perl>.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.
See L<MooseX::Getopt::Usage/BUGS> for details of how to report bugs.

=head1 ACKNOWLEDGEMENTS


=head1 AUTHOR

Mark Pitchless, C<< <markpitchless at gmail.com> >>

=head1 COPYRIGHT

Copyright 2012 Mark Pitchless 

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

