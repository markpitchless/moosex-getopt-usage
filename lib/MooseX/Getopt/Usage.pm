
package MooseX::Getopt::Usage;

use 5.010;
our $VERSION = '0.08';

use Moose::Role;
use Try::Tiny;
use MooseX::Getopt::Usage::Formatter;

with 'MooseX::Getopt::Basic';

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

sub getopt_usage_config { () }

sub getopt_usage {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my %args  = @_;
    my $conf  = { $class->getopt_usage_config, %args };
    if ( ! exists $conf->{colours} && exists $conf->{colors} ) {
        $conf->{colours} = delete $conf->{colors}
    }
    $conf->{getopt_class} = $class;
    my $fmtr = MooseX::Getopt::Usage::Formatter->new($conf);
    return $args{man} ? $fmtr->manpage(%args) : $fmtr->usage(%args);
}

# The way new_with_options decides if usage is needed does not fit our needs
# as we don't supply a usage object. So we do it here.
around new_with_options => sub {
    my $orig  = shift;
    my $class = shift;
    my $self;
    try {
        $self = $class->$orig(@_);
        $self->getopt_usage( man => 1)   if $self->can('man') and $self->man;
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
        when (/^Unknown option:|^Value .*? for option |Option .* does not take an argument/) {
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

=head1 VERSION

Version 0.08

=head1 SYNOPSIS

    ## In your class
    package My::App;
    use Moose;

    with 'MooseX::Getopt::Usage';

    has verbose => ( is => 'ro', isa => 'Bool', default => 0,
        documentation => qq{Say lots about what we are doing} );

    has gumption => ( is => 'rw', isa => 'Int', default => 23,
        documentation => qq{How much gumption to apply} );

    # ... rest of class

    ## In your script
    #!/usr/bin/perl
    use My::App;
    my $app = My::App->new_with_options;

Can now get help,

 $ synopsis.pl -?
 Usage:
     synopsis.pl [OPTIONS]
 Options:
     --help -? --usage - Bool. Display the usage message and exit
     --verbose         - Bool. Say lots about what we are doing
     --gumption        - Int. Default=23. How much gumption to apply

and trap errors with usage.

 $ synopsis.pl --elbowgrease --gumption=Lots
 Unknown option: elbowgrease
 Value "Lots" invalid for option gumption (number expected)
 Usage:
     synopsis.pl [OPTIONS]
 Options:
     --help -? --usage - Bool. Display the usage message and exit
     --verbose         - Bool. Say lots about what we are doing
     --gumption        - Int. Default=23. How much gumption to apply

=head1 DESCRIPTION

Perl Moose Role that extends L<MooseX::Getopt> to provide usage printing
that inspects your classes meta information to build a (coloured) usage
message including that meta information.

If stdout is a tty usage message is colourised. Setting the env var
ANSI_COLORS_DISABLED will disable colour even on a tty.

Errors in command line option parsing will be displayed along with the usage,
causing the program to exit with a non-zero status code when new_with_options
is used.

=head1 ATTRIBUTES

=head2 help_flag

Indicates if any of -?, --help, or --usage where given in the command line
args.

=head2 man

The --man option on the command line. If true after class construction
program will exit displaying the man generated from the POD.

=head1 METHODS

=head2 getopt_usage( %args )

Generate the usage message and return or output to stdout and exit. Without
exit arg returns the usage string, with an exit arg prints the usage to stdout
and exits with the given exit code.

 print $self->getopt_usage if $self->help_flag;

 $self->getopt_usage( exit => 10, err => "Their all dead, Dave" );

Options are printed required first, then optional.  These two sections get a
heading unless C<headings> arg or config is false.

%args can have any of the options from L</CONFIGURATION>, plus the following.

=over 4

=item exit

If an exit arg is given and defined then this method will exit the program with
that exit code after displaying usage to STDOUT.

=item err | error

Error message string to display before the usage. Will get the error highlight.

=back

=head2 getopt_usage_config

Return a hash (ie a list) of config to override the defaults. Default returns
empty list. See L</CONFIGURATION> for details.

=head1 CONFIGURATION

The configuration used is the defaults, followed by the return from
L</getopt_usage_config>, followed by any args passed direct to L</getopt_usage>.
The easiest way to configure the usage message is to override
L</getopt_usage_config> in your class. e.g. to use a more compact layout.

 use Moose;
 with 'MooseX::Getopt::Usage';

 sub getopt_usage_config {
    return (
        format   => "Usage: %c [OPTIONS]",
        headings => 0,
    );
 }

Availiable config is:

=head2 format

String to format the top of the usage message. %c is substituted for the
command name. Use %% for a literal %. Default:

    format => "Usage:\n    %c [OPTIONS]",

=head2 attr_sort

Sub ref used to sort the attributes and hence the order they appear in the
usage message. Default is the order the attributes are defined.

B<NB:> the sort terms ($a and $b) are passed as the first two arguments, do
B<not> use $a and $b (you will get warnings). The arguments will be
L<Moose::Meta::Attribute>s. e.g. to sort by name alphabetically:

    attr_sort => sub { $_[0]->name cmp $_[1]->name }

=head2 headings

Whether to add headings of 'Options:' and 'Required:' to the list of options.
Default is true.

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

=head2 unexpand

Set C<$Text::Wrap::unexpand>, see L<Text::Wrap/OVERRIDES>.

=head2 tabstop

Set C<$Text::Wrap::tabstop>, see L<Text::Wrap/OVERRIDES>.


=head1 EXAMPLE

Put this is a file called hello.pl and make it executable.

 #!/usr/bin/env perl
 package Hello;
 use Modern::Perl;
 use Moose;

 with 'MooseX::Getopt::Usage';

 has verbose => ( is => 'ro', isa => 'Bool',
     documentation => qq{Say lots about what we do} );

 has greet => ( is => 'ro', isa => 'Str', default => "World",
     documentation => qq{Who to say hello to.} );

 has times => ( is => 'rw', isa => 'Int', required => 1,
     documentation => qq{How many times to say hello} );

 sub run {
     my $self = shift;
     say "Printing message..." if $self->verbose;
     say "Hello " . $self->greet for (1..$self->times);
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
 Required:
     --times           - Int. How many times to say hello
 Options:
     --help -? --usage - Bool. Display the usage message and exit
     --verbose         - Bool. Say lots about what we do
     --greet           - Str. Default=World. Who to say hello to.

=head1 SEE ALSO

L<perl>, L<Moose>, L<MooseX::Getopt>, L<Term::ANSIColor>, L<Text::Wrap>,
L<Pod::Usage>.

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
