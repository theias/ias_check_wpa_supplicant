#!/usr/bin/perl

# Usage: iw dev <device> link | this script

use strict;
use warnings;

use lib '/opt/IAS/lib/perl5';
use FindBin qw($RealBin);
use lib "$RealBin/../lib/perl5";

use JSON;
use Data::Dumper;
$Data::Dumper::Sortkeys=1;
$Data::Dumper::Indent=1;

use IAS::IW::LinkParser;

use Getopt::Long;

our %OUTPUT_MODE_DISPATCH = (
	'json' => \&output_json,
	'dumper' => \&output_dumper,
);

my $OPTIONS_VALUES = {
	'mode' => 'dumper',
};

my @OPTIONS = (
	'mode=s',
	'pretty!',
);

GetOptions(
	$OPTIONS_VALUES,
	@OPTIONS
) or usage();

if (
	! defined $OUTPUT_MODE_DISPATCH{$OPTIONS_VALUES->{'mode'}})
{
	usage();
}

my $input;
{
	local $/;
	$input = <STDIN>;
}

my $output = IAS::IW::LinkParser::parse_link_info($input);
$OUTPUT_MODE_DISPATCH{$OPTIONS_VALUES->{'mode'}}->($output);


exit;

sub output_dumper
{
	my ($output) = @_;
	print Dumper($output),$/;
}

sub output_json
{
	my ($output) = @_;
	my $json = JSON->new->allow_nonref();
	$json->canonical([1]);
	if ($OPTIONS_VALUES->{'pretty'})
	{
		$json->pretty([1]);
	}
	print $json->encode($output),$/;
}

sub usage
{
	print "Options:\n",$/;
	print Dumper(\@OPTIONS);

	print "\nModes:\n";
	print "\t",join("\n\t", sort keys %OUTPUT_MODE_DISPATCH),$?;
	exit 1;
}

