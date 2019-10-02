package IAS::IW::LinkParser;

sub parse_link_info
{
	my ($link_info) = @_;

	my $link_data = {};
	
	my @link_lines = split(/\n/, $link_info);
	
	my $line = shift @link_lines;
	
	$line =~ m/Connected to\s+(\S+)/;
	$link_data->{'access_point'} = $1;
	
	LINK_LINE: while (scalar @link_lines)
	{
		$line = shift @link_lines;
		
		$line =~ s/^\s*//;
		$line =~ s/\s*$//;
		
		next LINK_LINE if ($line =~ m/^\s*$/);
		my $stuff = parse_arbitary_delimited(':', $line);
		if (! defined $stuff->[1])
		{
			print "Bad line: $line\n";
		}
		$link_data->{$stuff->[0]} = $stuff->[1];
		
		if ($stuff->[1] =~ m/(\d+)\s+bytes\s+\((\d+)\s+packets/)
		{
			$link_data->{'__'.$stuff->[0].'_bytes'} = $1;
			$link_data->{'__'.$stuff->[0].'_packets'} = $2;
		}
	}
	return $link_data;	
}

sub parse_arbitary_delimited
{
	my ($delimiter, $data) = @_;

	my @data_parts = split(/$delimiter/, $data,2);
	trim_array_reference(\@data_parts);

	return \@data_parts;
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
