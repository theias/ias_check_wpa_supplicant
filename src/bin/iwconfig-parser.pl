#!/usr/bin/perl

use strict;
use warnings;

use lib '/opt/IAS/lib/perl5';
use FindBin qw($RealBin);
use lib "$RealBin/../lib/perl5";

use JSON;
use Data::Dumper;
$Data::Dumper::Sortkeys=1;
$Data::Dumper::Indent=1;

use IAS::IWConfig::Parser;

my $iwconfig_command = 'iwconfig wlp2s0';

my $output = `$iwconfig_command`;

print Dumper(IAS::IWConfig::Parser::parse_iwconfig_output($output)),$/;

exit;


