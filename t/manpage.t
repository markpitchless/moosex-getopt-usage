#!/usr/bin/perl

use FindBin qw($Bin);
use lib ("$Bin/lib");
use ManPage::Test;
Test::Class->runtests;
