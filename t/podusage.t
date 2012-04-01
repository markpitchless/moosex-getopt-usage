#!/usr/bin/perl

use FindBin qw($Bin);
use lib ("$Bin/lib");
use PodUsage::Test;
Test::Class->runtests;
