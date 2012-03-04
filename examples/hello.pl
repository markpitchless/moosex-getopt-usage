#!/usr/bin/env perl
package Hello;
use Modern::Perl;
use Moose;

with 'MooseX::Getopt::Basic', 'MooseX::Getopt::Usage';

has verbose => ( is => 'ro', isa => 'Bool',
    documentation => qq{Say lots about what we do} );

has greet => ( is => 'ro', isa => 'Str', default => "World",
    documentation => qq{Who to say hello to.} );

sub run {
    my $self = shift;

    $self->getopt_usage( exit => 0 ) if $self->help_flag;

    say "Printing message..." if $self->verbose;
    say "Hello " . $self->greet;
}

package main;
Hello->new_with_options->run;
