package Basic;
use strict;
use warnings;

use Moose;
with 'MooseX::Getopt::Basic', 'MooseX::Getopt::Usage';

has verbose => ( is => 'ro', isa => 'Bool',
    documentation => qq{Say lots about what we do} );

has greet => ( is => 'ro', isa => 'Str', default => "World",
    documentation => qq{Who to say hello to.} );

1;
