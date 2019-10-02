#!/usr/bin/perl

use strict;
use warnings;

my $iwconfig_command = 'iwconfig wlp2s0';

my $output = `$iwconfig_command`;

use Data::Dumper;

print Dumper(parse_iwconfig_output($output)),$/;

exit;

sub parse_iwconfig_output
{
	my ($iwconfig_output) = @_;


	my @iwconfig_lines = split(/\n/, $iwconfig_output);

	my $iwconfig_data = {};

	# The first line
	#   Begins with the device name ^\S+
	#   Has whitespace \s+
	#   Then we grab the rest of the line (.*)
	#   Which contains IEEE 802.11 , and the ESSID
	my $line = shift @iwconfig_lines;
	$line =~ m/^\S+\s+(.*)$/;

	my $first_rest = $1;

	my $line_parts = parse_double_space_delimited_data($first_rest);

	$iwconfig_data->{type} = shift @$line_parts;

	my $ssid_parts = parse_arbitary_delimited(':',shift @$line_parts);

	$ssid_parts->[1] =~ s/^"//;
	$ssid_parts->[1] =~ s/"$//;
	
	$iwconfig_data->{$ssid_parts->[0]} = $ssid_parts->[1];

	$line = shift @iwconfig_lines;
	
	foreach $line (@iwconfig_lines)
	{
	  
	}
	
	return $iwconfig_data;
}

sub parse_arbitary_delimited
{
	my ($delimiter, $data) = @_;

	my @data_parts = split(/$delimiter/, $data);
	trim_array_reference(\@data_parts);

	return \@data_parts;
}


sub parse_double_space_delimited_data{
	my ($line) = @_;

	my @line_parts = split(/\s\s+/, $line);
	trim_array_reference(\@line_parts);

	return \@line_parts;
}

sub trim_array_reference
{
	my ($ar) = @_;

	foreach (@$ar)
	{
	  $_ =~s/^\s*//;
	  $_ =~s/\s*$//;
	}
}
