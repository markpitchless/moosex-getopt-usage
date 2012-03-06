
package MooseX::Getopt::Usage;

use 5.010;
our $VERSION = '0.03';

use Moose::Role;
use Try::Tiny;
use Term::ANSIColor;
use Term::ReadKey;
use Text::Wrap;
use File::Basename;

with 'MooseX::Getopt::Basic';

our $DefaultConfig = {
    format    => "Usage:\n    %c [OPTIONS]",
    attr_sort => sub { 0 },
    colours   => {
        flag          => ['yellow'],
        heading       => ['bold'],
        command       => ['green'],
        type          => ['magenta'],
        default_value => ['cyan'],
        error         => ['red']
    }
};

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

# As we don't use GLD insert our own help_flag.
has help_flag => (
    is            => 'rw',
    isa           => 'Bool',
    traits        => ['Getopt'],
    cmd_flag      => 'help',
    cmd_aliases   => [qw/? usage/],
    documentation => "Display the usage message and exit"
);

# Promote warnings to errors to capture invalid and missing options errors from
# Getopt::Long::GetOptions.
around _getopt_spec_warnings => sub {
    shift; my $class = shift;
    die @_;
};

sub _getopt_usage_parse_format {
    my $self    = shift;
    my $conf    = shift or confess "No config";
    my $fmt     = shift or confess "No format";
    my $colours = $conf->{colours};

    $fmt =~ s/%c/colored $colours->{command}, _prog_name()/ieg;
    $fmt =~ s/%%/%/g;
    # TODO - Be good to have a include that generates a list of the opts
    #        %r - required  %a - all  %o - options
    $fmt =~ s/^(Usage:)/colored $colours->{heading}, "$1"/e;
    $self->_getopt_usage_colourise($conf, \$fmt);
    return $fmt;
}

sub getopt_usage_config { () }

sub getopt_usage {
    my $self = shift;
    my $conf = { %$DefaultConfig, $self->getopt_usage_config, @_ };
    if ( ! exists $conf->{colours} && exists $conf->{colors} ) {
        $conf->{colours} = delete $conf->{colors}
    }
    #use Data::Dumper; say .Dumper($conf);

    my $colours   = $conf->{colours};
    my $exit      = $conf->{exit};
    my $headings  = $conf->{no_headings} ? 0 : 1;
    my $err       = $conf->{err} || $conf->{error} || "";
    my $format    = $conf->{format};
    my $attr_sort = $conf->{attr_sort};

    say colored $colours->{error}, $err if $err;
    say $self->_getopt_usage_parse_format($conf, $format) if $headings;

    my @attrs = sort { $attr_sort->($a, $b) } $self->_compute_getopt_attrs;

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
    say colored $colours->{heading}, "Required:" if $headings && @req_attrs;
    $self->_getopt_usage_attr($conf, $_, max_len => $max_len ) foreach @req_attrs;
    say colored $colours->{heading}, "Options:" if $headings && @opt_attrs;
    $self->_getopt_usage_attr($conf, $_, max_len => $max_len ) foreach @opt_attrs;

    exit $exit if defined $exit;
    return 1;
}

# Return the full label, including aliases and dashes, for the passed attribute
sub _getopt_usage_attr_label {
    my $self = shift;
    my $attr = shift || confess "No attr";
    my ( $flag, @aliases ) = $self->_get_cmd_flags_for_attr($attr);
    my $label = join " ", map {
        length($_) == 1 ? "-$_" : "--$_"
    } ($flag, @aliases);
    return $label;
}

# Return the formated and coloured usage string for the passed attribute.
sub _getopt_usage_attr {
    my $self    = shift;
    my $conf    = shift or confess "No config";
    my $attr    = shift or confess "No attr";
    my %args    = @_;
    my $colours = $conf->{colours};
    my $max_len = $args{max_len} or confess "No max_len";

    local $Text::Wrap::unexpand = 0;
    local $Text::Wrap::tabstop  = 4;

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
    $self->_getopt_usage_colourise($conf, \$out);
    say $out;
}

# Extra colourisation for the attributes usage string. Think syntax highlight.
sub _getopt_usage_colourise {
    my $self    = shift;
    my $conf    = shift or confess "No config";
    my $out     = shift || "";
    my $colours = $conf->{colours};

    my $str = ref $out ? $out : \$out;
    $$str =~ s/(--?\w+)/colored $colours->{flag}, "$1"/ge;
    return ref $out ? $out : $$str;
}

# The way new_with_options decides if usage is needed does not fit our needs
# as we don't supply a usage object. So we do it here.
around new_with_options => sub {
    my $orig  = shift;
    my $class = shift;
    my $self;
    try {
        $self = $class->$orig(@_);
        $self->getopt_usage( exit => 0 ) if $self->help_flag;
        return $self;
    }
    catch {
        when (
            /Attribute \((\w+)\) does not pass the type constraint because: (.*?) at/
        ) {
            $class->getopt_usage( exit => 1, err => "Invalid '$1' : $2" );
        }
        when (/Attribute \((\w+)\) is required /) {
            $class->getopt_usage( exit => 2, err => "Required option missing: $1" );
        }
        when (/^Unknown option:|^Value .*? for option/) {
            # Getopt::Long warnings we promoted in _getopt_spec_warnings
            s/\n+$//;
            $class->getopt_usage( exit => 3, err => $_ );
        }
        default {
            die $_;
        }
    };
};

no Moose::Role;

1;
__END__

=pod

=head1 NAME

MooseX::Getopt::Usage - Extend MooseX::Getopt with usage message generated from attribute meta.

=cut

=head1 SYNOPSIS

 use Moose;

 with 'MooseX::Getopt::Usage';

 has verbose => ( is => 'ro', isa => 'Bool', default => 0,

=head1 DESCRIPTION

Perl Moose Role that extends L<MooseX::Getopt> to provide a usage printing
that inspects your classes meta information to build a (coloured) usage
message including that meta information.

=head1 ATTRIBUTES

=head2 help_flag

Indicates if any of -?, --help, or --usage where given in the command line
args.

=head1 METHODS

=head2 getopt_usage( %args )

Prints the usage message to stdout followed by a table of the options. Options
are printed required first, then optional.  These two sections get a heading
unless C<no_headings> arg is true.

If stdout is a tty usage message is colourised. Setting the env var
ANSI_COLORS_DISABLED will disable colour even on a tty.

If an exit arg is given and defined then this method will exit the program with
that exit code.

=head2 getopt_usage_config

Return a hash (ie a list) of config to override the defaults. Default returns
empty hash so you get the defaults. See L</CONFIGURATION> for details.

=head1 CONFIGURATION

The configuration used is the defaults, followed by the return from
L</getopt_usage_config>, followed by any args passed direct to L</getopt_usage>.
The easiest way to configure the usage message is to override
L</getopt_usage_config> in your class. e.g.

 use Moose;
 with 'MooseX::Getopt::Usage';

 sub getopt_usage_config {
    return ( attr_sort => sub { $_[0]->name cmp $_[1]->name } );
 }

Availiable config is:

=head2 format

String to format the top of the usage message. %c is substituted for the
command name. Use %% for a literal %. Default:

    format => "Usage:\n    %c [OPTIONS]",

=head2 attr_sort

Sub ref used to sort the attributes and hence the order they appear in the
usage message. Default is the order the are defined.

B<NB:> the sort terms ($a and $b) are passed as the first two arguments, do not
use $a and $b (you will get warnings).

=head2 exit

=head2 no_headings

=head2 err | error

=head2 colours | colors

Hash ref mapping highlight names to colours, given as strings to pass to
L<Term::ANSIColor>. Default looks like this:

    colours   => {
        flag          => ['yellow'],
        heading       => ['bold'],
        command       => ['green'],
        type          => ['magenta'],
        default_value => ['cyan'],
        error         => ['red']
    }

=head1 EXAMPLE

Put this is a file called hello.pl and make it executable.

    #!/usr/bin/env perl
    package Hello;
    use Modern::Perl;
    use Moose;

    with 'MooseX::Getopt::Basic', 'MooseX::Getopt::Usage';

    has verbose => ( is => 'ro', isa => 'Bool',
        documentation => qq{Say lots about what we do} );

    has greet => ( is => 'ro', isa => 'Str', default => "World",
        documentation => qq{Who to say hello to} );

    sub run {
        my $self = shift;
        say "Printing message..." if $self->verbose;
        say "Hello " . $self->greet;
    }

    package main;
    Hello->new_with_options->run;

Then call with any of these to get usage output.

 $ ./hello.pl -?
 $ ./hello.pl --help
 $ ./hello.pl --usage

Which will look a bit like this, only in colour.

 Usage:
     hello.pl [OPTIONS]
 Options:
     --help -? --usage - Bool. Display usage message
     --verbose         - Bool. Say lots about what we do
     --greet           - Str. Default=World. Who to say hello to.


=head1 SEE ALSO

L<perl>, L<Moose>, L<MooseX::Getopt>.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.
Please report any bugs or feature requests via the github page at:

L<http://github.com/markpitchless/moosex-getopt-usage>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MooseX::Getopt::Usage

The source code and other information is hosted on github:

L<http://github.com/markpitchless/moosex-getopt-usage>

=head1 AUTHOR

Mark Pitchless, C<< <markpitchless at gmail.com> >>

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2012 Mark Pitchless

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
