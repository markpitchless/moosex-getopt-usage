package MooseX::Getopt::Usage::Formatter;

use 5.010;
our $VERSION = '0.01';

use Moose;
#use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Term::ANSIColor;
use Term::ReadKey;
use Text::Wrap;
use Pod::Usage;
use Pod::Select;
use Pod::Find qw(pod_where);
use File::Slurp qw(slurp);
use File::Basename;

BEGIN {
    # Grab prog name before someone decides to change it.
    my $prog_name;
    sub prog_name { @_ ? ($prog_name = shift) : $prog_name }
    prog_name(File::Basename::basename($0));
}

# Util wrapper for pod select and its file based API
sub podselect_text {
    my @args = @_;
    my $selected = "";
    open my $fh, ">", \$selected or die;
    if ( exists $args[0] and ref $args[0] eq "HASH" ) {
        $args[0]->{'-output'} = $fh;
    }
    else {
        unshift @args, { '-output' => $fh };
    }
    podselect @args;
    return $selected;
}

has getopt_class => (
    is       => "rw",
    isa      => "ClassName",
    required => 1,
);

has pod_file => (
    is      => "rw",
    isa     => "Undef|Str",
    lazy_build => 1,
);

sub _build_pod_file {
    my $self = shift;
    my $file = pod_where( {-inc => 1}, $self->getopt_class );
    return $file;
}


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
    lazy_build => 1,
);

sub _build_format {
    my $self = shift;
    my $pod_file = $self->pod_file;
    my $selected = "";
    if ( $pod_file ) {
        $selected = podselect_text {-sections => ["SYNOPSIS"] }, $pod_file;
        $selected =~ s{^=head1.*?\n$}{}mg;
        $selected =~ s{^.*?\n}{};
        $selected =~ s{\n$}{};
    }
    return $selected ? $selected : "    %c [OPTIONS]";
}

has attr_sort => (
    is      => "rw",
    isa     => "CodeRef",
    default => sub { sub {0} },
);

enum 'ColorUsage', [qw(auto never always env)];

has use_color => (
    is      => "rw",
    isa     => "ColorUsage",
    default => "auto",
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

sub _set_color_handling {
    my $self = shift;
    my $mode = shift;

    $ENV{ANSI_COLORS_DISABLED} = defined $ENV{ANSI_COLORS_DISABLED} ? 1 : undef;
    given ($mode) {
        when ('auto') {
            if ( not defined $ENV{ANSI_COLORS_DISABLED} ) {
                $ENV{ANSI_COLORS_DISABLED} = -t STDOUT ? undef : 1;
            }
        }
        when ('always') {
            $ENV{ANSI_COLORS_DISABLED} = undef;
        }
        when ('never') {
            $ENV{ANSI_COLORS_DISABLED} = 1;
        }
        # 'env' is done in the local line above
    }
}

sub usage {
    my $self = shift;
    my $args = { @_ };

    my $exit = $args->{exit};
    my $err  = $self->{err} || "";

    my $colours   = $self->colours;
    my $headings  = defined $args->{headings} ? $args->{headings} : $self->headings;
    my $format    = $args->{format}   || $self->format;
    my $options   = defined $args->{options} ? $args->{options} : 1;

    # Set the color handling for this call
    $self->_set_color_handling( $args->{use_color} || $self->use_color );

    my $out = "";
    $out .= colored($colours->{error}, $err)."\n" if $err;
    $out .= colored($colours->{heading}, "Usage:")."\n" if $headings;
    $out .= $self->_parse_format($format)."\n";
    $out .= $self->_options_text if $options;

    if ( defined $exit ) {
        print $out;
        exit $exit;
    }
    return $out;
}

sub _options_text {
    my $self = shift;
    my $args = { @_ };

    my $gclass    = $self->getopt_class;
    my $colours   = $self->colours;
    my $headings  = defined $args->{headings} ? $args->{headings} : $self->headings;
    my $attr_sort = $self->attr_sort;

    my @attrs = sort { $attr_sort->($a, $b) } $gclass->_compute_getopt_attrs;
    my $max_len = 0;
    my (@req_attrs, @opt_attrs);
    foreach (@attrs) {
        my $len  = length($self->_attr_label($_));
        $max_len = $len if $len > $max_len;
        if ( $_->is_required && !$_->has_default && !$_->has_builder ) {
            push @req_attrs, $_;
        }
        else {
            push @opt_attrs, $_;
        }
    }

    my $out = "";
    $out .= colored($colours->{heading}, "Required:")."\n"
        if $headings && @req_attrs;
    $out .= $self->_attr_str($_, max_len => $max_len )."\n"
        foreach @req_attrs;
    $out .= colored($colours->{heading}, "Options:")."\n"
        if $headings && @opt_attrs;
    $out .= $self->_attr_str($_, max_len => $max_len )."\n"
        foreach @opt_attrs;

    return $out;
}

sub manpage {
    my $self   = shift;
    my $gclass = $self->getopt_class;

    $self->_set_color_handling('never');

    my $pod = podselect_text( $self->pod_file );
    # XXX Some dirty pod regexp hacking. Needs moving to Pod::Parser.
    # Insert SYNOPSIS if not there. After NAME or top of pod.
    unless ($pod =~ m/^=head1\s+SYNOPSIS\s*$/ms) {
        my $synopsis = "\n=head1 SYNOPSIS\n\n".$self->format."\n";
        if ($pod =~ m/^=head1\s+NAME\s*$/ms) {
            $pod =~ s/(^=head1\s+NAME\s*\n.*?)(^=|\z)/$1$synopsis\n\n$2/ms;
        }
        else {
            $pod = "$synopsis\n$pod";
        }
    }
    # Insert OPTIONS if not there. After DESCRIPTION or end of pod.
    unless ($pod =~ m/^=head1\s+OPTIONS\s*$/ms) {
        my $newpod = "\n=head1 OPTIONS\n\n";
        if ($pod =~ m/^=head1\s+DESCRIPTION\s*$/ms) {
            $pod =~ s/(^=head1\s+DESCRIPTION\s*\n.*?)(^=|\z)/$1$newpod$2/ms;
        }
        else {
            $pod = "$pod\n$newpod";
        }
    }

    # Process the SYNOPSIS
    $pod =~ s/(^=head1\s+SYNOPSIS\s*\n)(.*?)(^=|\z)/$1.$self->_parse_format($2).$3/mes;

    # Add options list to OPTIONS
    #my @attrs = sort { $attr_sort->($a, $b) } $self->_compute_getopt_attrs;
    my $options_pod = "";
    my @attrs = $gclass->_compute_getopt_attrs;
    $options_pod .= "=over 4\n\n";
    foreach my $attr (@attrs) {
        my $label = $self->_attr_label($attr);
        $options_pod .= "=item B<$label>\n\n";
        $options_pod .= $attr->documentation."\n\n";
    }
    $options_pod .= "=back\n\n";
    $pod =~ s/(^=head1\s+OPTIONS\s*\n.*?)(^=|\z)/$1\n$options_pod$2/ms;

    open my $fh, "<", \$pod or die;
    pod2usage( -verbose => 2, -input => $fh );
}

sub _parse_format {
    my $self    = shift;
    my $fmt     = shift or confess "No format";
    my $colours = $self->colours;

    $fmt =~ s/%c/colored $colours->{command}, prog_name()/ieg;
    $fmt =~ s/%%/%/g;
    # TODO - Be good to have a include that generates a list of the opts
    #        %r - required  %a - all  %o - options
    $fmt =~ s/^(Usage:)/colored $colours->{heading}, "$1"/e;
    $self->_colourise(\$fmt);
    return $fmt;
}


# Return the full label, including aliases and dashes, for the passed attribute
sub _attr_label {
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
sub _attr_str {
    my $self    = shift;
    my $attr    = shift or confess "No attr";
    my %args    = @_;
    my $max_len = $args{max_len} or confess "No max_len";
    my $colours = $self->colours;

    my ($w) = GetTerminalSize;
    local $Text::Wrap::columns = $w -1 || 72;
    local $Text::Wrap::unexpand = $self->unexpand;
    local $Text::Wrap::tabstop  = $self->tabstop;

    my $label = $self->_attr_label($attr);

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
    $self->_colourise(\$out);
    return $out;
}

# Extra colourisation for the attributes usage string. Think syntax highlight.
sub _colourise {
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

=head1 FUNCTIONS

=head2 podselect_text

=head1 METHODS

=head2 usage

=head2 manpage

=head2 prog_name

The name of the program, grabbed at BEGIN time before someone decides to
change it.

=head1 SEE ALSO

L<Moose>, L<perl>.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.
See L<MooseX::Getopt::Usage/BUGS> for details of how to report bugs.

=head1 ACKNOWLEDGEMENTS

Thanks to Hans Dieter Pearcey for prog name grabbing. See L<Getopt::Long::Descriptive>.

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

