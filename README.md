MooseX-Getopt-Usage
===================

Extend MooseX::Getopt with usage message and man page generated from attribute meta and POD.

SYNOPSIS
--------

```perl

    ## In your class
    package My::App;
    use Moose;

    with 'MooseX::Getopt::Usage',
         'MooseX::Getopt::Usage::Role::Man';

    has verbose => ( is => 'ro', isa => 'Bool', default => 0,
        documentation => qq{Say lots about what we are doing} );

    has gumption => ( is => 'rw', isa => 'Int', default => 23,
        documentation => qq{How much gumption to apply} );

    # ... rest of class

    ## In your script
    #!/usr/bin/perl
    use My::App;
    my $app = My::App->new_with_options;
```

Can now get help,

```sh
 $ synopsis.pl -?
 Usage:
     synopsis.pl [OPTIONS]
 
 Options:
      --man             - Bool. Display man page
      --help -? --usage - Bool. Display the usage message and exit
      --verbose         - Bool. Say lots about what we are doing
      --gumption        - Int. Default=23. How much gumption to apply
```

trap errors with usage,

```sh
 $ synopsis.pl --elbowgrease --gumption=Lots
 Unknown option: elbowgrease
 Value "Lots" invalid for option gumption (number expected)
 Usage:
     synopsis.pl [OPTIONS]
 
 Options:
      --man             - Bool. Display man page
      --help -? --usage - Bool. Display the usage message and exit
      --verbose         - Bool. Say lots about what we are doing
      --gumption        - Int. Default=23. How much gumption to apply
```

and get a man page:

```sh
 $ synopsis.pl --man
```
