package IAS::IWConfig::Parser;

sub parse_iwconfig_output
{
	my ($iwconfig_output, $iwconfig_data) = @_;

	$iwconfig_data ||= {};
	
	my @iwconfig_lines = split(/\n/, $iwconfig_output);

	my $iwconfig_data = {};

	# The first line
	#  Begins with the device name ^\S+
	#  Has whitespace \s+
	#  Then we grab the rest of the line (.*)
	#  Which contains IEEE 802.11 , and the ESSID
	#  unless it doesn't have wireless extensions.
	
	IWCONFIG_DEVICE: while (scalar @iwconfig_lines)
	{
		my $line = shift @iwconfig_lines;
		$line =~ m/^(\S+)\s+(.*)$/;

		my $device = $1;
		my $device_data = {};
		$iwconfig_data->{$device} = $device_data;
		
		my $first_rest = $2;

		if ($first_rest =~ m/no wireless/)
		{
			# This probaby never gets run, because the output
			# complaining about not having wireless extensions
			# is printed to stderr
			$device_data->{__type} = $first_rest;
			next IWCONFIG_DEVICE;
		}

		my $line_parts = parse_double_space_delimited_data($first_rest);

		$device_data->{__type} = shift @$line_parts;

		my $ssid_parts = parse_arbitary_delimited(':',shift @$line_parts);

		$ssid_parts->[1] =~ s/^"//;
		$ssid_parts->[1] =~ s/"$//;
		
		$device_data->{$ssid_parts->[0]} = $ssid_parts->[1];

		parse_continuing_lines($device_data, \@iwconfig_lines);
	}	
	return $iwconfig_data;
}

sub parse_continuing_lines
{
	my ($device_data, $iwconfig_lines) = @_;
	
	
	while (scalar @$iwconfig_lines)
	{
		# Did we find the next device?
		return if ($iwconfig_lines->[0] =~ m/^(\S)/);
		
		$line = shift (@$iwconfig_lines);
		$line =~ s/^\s*//;
		$line =~ s/\s*$//;
		
		$line_parts = parse_double_space_delimited_data($line);
		
		foreach my $line_part (@$line_parts)
		{
			decide_what_to_do($device_data, $line_part);
		}
	}
	
}

sub decide_what_to_do
{
	my ($device_data, $line_part) = @_;

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
			$device_data->{$ar->[0]} = $ar->[1];
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
