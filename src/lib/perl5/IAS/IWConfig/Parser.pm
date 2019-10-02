package IAS::IWConfig::Parser;

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

	$iwconfig_data->{__type} = shift @$line_parts;

	my $ssid_parts = parse_arbitary_delimited(':',shift @$line_parts);

	$ssid_parts->[1] =~ s/^"//;
	$ssid_parts->[1] =~ s/"$//;
	
	$iwconfig_data->{$ssid_parts->[0]} = $ssid_parts->[1];
	
	foreach $line (@iwconfig_lines)
	{
		$line =~ s/^\s*//;
		$line =~ s/\s*$//;
		
		$line_parts = parse_double_space_delimited_data($line);
		
		foreach my $line_part (@$line_parts)
		{
			decide_what_to_do($iwconfig_data, $line_part);
		}
	}
	
	return $iwconfig_data;
}

sub decide_what_to_do
{
	my ($iwconfig_data, $line_part) = @_;

=pod

The output of iwconfig seems silly.

Some fields are delimited by ": ", or ":", or "=".
But, the bytes in the access point are also separated by ":".

So, we come up with a priority for parsing things.

If it has a ": " in it, that means "Left side: right side", and we're done.
If it has a ":" in it, then that means "Left side:right side", and we're done.
If it has a "=" in it, that means "Left side=right side", and we're done.

=cut
	
	my $data_parts = [];
	my @parse_priorities = (': ', ':', '=');
	
	PARSE_PRIORITY: foreach my $parse_priority (@parse_priorities)
	{
		if ($line_part =~ m/$parse_priority/)
		{
			my $ar = parse_arbitary_delimited($parse_priority, $line_part);
			$iwconfig_data->{$ar->[0]} = $ar->[1];
			return;
		}
	}
	print STDERR "MISSED: $line_part\n";
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

1;
