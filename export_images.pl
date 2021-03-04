#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use POSIX;
use IPC::Open3;

my ($id, $pid, $numpages, $label, $date);
my %gid2img = ();
my %gid2alto = ();
my %alto2gid = ();
my %alto2page = ();
my $currgroup;
my $debug = 0;
my @coordinateKeys = ('width', 'height', 'hpos', 'vpos', 'pageHeight', 'pageWidth');

if (scalar(@ARGV) == 0) {
	print "usage: export_images.pl metsfile\n";
	exit;
}

open(FIL, $ARGV[0]) || die "cannot open $ARGV[0] for reading\n";

if ($ARGV[0] =~ /([0-9]+)\.xml/) {
	$pid = $1;
} else {
	$pid = '0';
}
my $stage = 0;
my $imgdivOpen = 0;
my @labels;
my @types;
my @illustrations;

while (<FIL>) {
	if (/<mods:recordIdentifier>([^<]*)/) {
		$id = $1;
	}
	if (/<mets .*LABEL=\"([^"]*)\"/) {
		$label = $1;
	}
	if (/<mods:dateIssued[^>]*>([^<]*)/) {
		$date = $1;
	}
	if ($stage == 0) {
		if (/<fileGrp .*ID="IMGGRP"/) {
			$stage = 1;
		} elsif (/<fileGrp .*ID="ALTOGRP"/) {
			$stage = 2;
		} elsif (/<structMap.*TYPE="LOGICAL"/) {
			$stage = 3;
		}
	} elsif ($stage == 1) {
		if (/<\/fileGrp>/) {
			$stage = 0;
		} elsif (/<file.*ID="([^"]*)\".*GROUPID="([^"]*)\"/) {
			$currgroup = $2;
		} elsif (/<file.*GROUPID="([^"]*)\".*ID="([^"]*)\"/) {
			$currgroup = $1;
		} elsif (/<FLocat.*href="file:\/\/([^"]*)/) {
			$gid2img{$currgroup} = $1;
		}
	} elsif ($stage == 2) {
		if (/<\/fileGrp>/) {
			$stage = 0;
		} elsif (/<file.*ID="([^"]*)\".*GROUPID="([^"]*)\"/) {
			$alto2gid{$1} = $2;
			$currgroup = $2;
		} elsif (/<file.*GROUPID="([^"]*)\".*ID="([^"]*)\"/) {
			$alto2gid{$2} = $1;
			$currgroup = $1;
		} elsif (/<FLocat.*href="file:\/\/([^"]*)/) {
			$gid2alto{$currgroup} = $1;
		}
	} elsif ($stage == 3) {
		if (/<\/structMap/) {
			$stage = 0;
		}
		my ($divType, $label) = &extractDiv($_);
		if ($divType) {
			push(@labels, $label);
			push(@types, $divType);
			if ($divType eq "ILLUSTRATION" || $divType eq "MAP" || $divType eq "CHART_DIAGRAM") {
				$stage = 4;
				$imgdivOpen = 1;
				my %entry = ('caption' => $label);
				push @illustrations, \%entry;
				my @img = ();
				$illustrations[-1]->{'img'} = [];
				my @aut = ();
				$illustrations[-1]->{'author'} = [];
				$illustrations[-1]->{'metsDivType'} = $divType
			}
		} elsif (/<\/div/) {
			pop @labels;
			pop @types;
		}
	} elsif ($stage == 4) {
		my ($divType, $label) = &extractDiv($_);
		if ($divType) {
			$imgdivOpen++;
			if ($divType eq "IMAGE") {
				$stage = 5;
			}
		} elsif (/<\/div/) {
			$imgdivOpen--;
			if ($imgdivOpen < 1) {
				$stage = 3;
			}
		}
	} elsif ($stage == 5) {
		my ($fileid, $begin);
		if (/<area.*FILEID="([^"]*)\".*BEGIN="([^"]*)"/) {
			$fileid = $1;
			$begin = $2;
			push @{$illustrations[-1]->{'img'}}, { ($fileid => {$begin => scalar(@illustrations)} ) };
		} elsif (/<area.*BEGIN="([^"]*)".*FILEID="([^"]*)"/) {
			$fileid = $2;
			$begin = $1;
			push @{$illustrations[-1]->{'img'}}, { ($fileid => {$begin => scalar(@illustrations)} ) };
		} elsif (/<\/div/) {
			$imgdivOpen--;
			$stage = 4;
		}
	}
}

close(FIL);

if (scalar(@illustrations) < 1) {
	exit 0;
}

# define the output directory
my $outputdir;
if ($pid) {
	$outputdir = 'norecordid/'.$pid.'/';
}
if ($id) {
        $outputdir = $id.'/';
}

$numpages = scalar(keys %alto2gid);

# Number the pages in the order that the alto IDs are ordered
my $counter = 1;
foreach my $k (sort keys %alto2gid) {
	$alto2page{$k} = $counter;
	$counter++;
}

# Spread the illustrations which have more than one image into several illustrations with the same metadata
my @ill;
for (my $i = 0; $i < scalar(@illustrations); ++$i) {
	for (my $k = 0; $k < scalar(@{$illustrations[$i]->{'img'}}); $k++) {
		foreach my $a (keys %{$illustrations[$i]->{'img'}->[$k]}) {
			foreach my $b (keys %{$illustrations[$i]->{'img'}->[$k]->{$a}}) {
				push @ill, { 'caption' => $illustrations[$i]->{'caption'}, 'author' => $illustrations[$i]->{'author'}, 'altoid' => $a, 'blockid' => $b , 'metsDivType' => $illustrations[$i]->{'metsDivType'} , 'page' => $alto2page{$a} }
			}
		}
	}
}

if ($debug > 1) {
	print "------------ @ill ------------\n";
	print Dumper(@ill);
	print "------------------------------\n";
}


# Collect all the images to be extracted together in a per-alto structure
my %alto2extraction = ();


for (my $i = 0; $i < scalar(@ill); ++$i) {
	my $a = $ill[$i]->{'altoid'};
	my $b = $ill[$i]->{'blockid'};
	if (!defined $alto2extraction{$a}) {
		my %ref;
		$alto2extraction{$a} = \%ref;
	}
	$alto2extraction{$a}->{$b} = $i;
}

# read each alto file as needed and crop the images
my $cropcmd = "";

foreach my $k (keys %alto2extraction) {
	my $res = &readAlto($k, $alto2extraction{$k});
	$cropcmd = $cropcmd."source: ".$gid2img{$alto2gid{$k}}."\n";
	for (my $i = 0; $i < scalar(@{$res}); $i++) {
		my $currIll = $res->[$i]->{'ILLUSTRATION_ID'};
		foreach my $blk (keys %{$res->[$i]}) {
			$ill[$currIll]->{$blk} = $res->[$i]->{$blk};
		}
		$ill[$currIll]->{'MM10pageWidth'} = $ill[$currIll]->{'pageWidth'};
		$ill[$currIll]->{'MM10pageHeight'} = $ill[$currIll]->{'pageHeight'};
		for (my $c = 0; $c < scalar(@coordinateKeys); ++$c) {
			$ill[$currIll]->{$coordinateKeys[$c]} = &mm10toPixel($ill[$currIll]->{$coordinateKeys[$c]});
		}
		$cropcmd = $cropcmd."crop ".$ill[$currIll]->{'width'}."x".$ill[$currIll]->{'height'}."+".$ill[$currIll]->{'hpos'}."+".$ill[$currIll]->{'vpos'}." ";
		$cropcmd = $cropcmd.$outputdir.$pid."-".$k."-".$ill[$currIll]->{'blockid'}.".jpg\n";
	}
	$cropcmd = $cropcmd."docrop\n";
}
if ($debug > 1) {
	print "-------- @ill after alto -----\n";
	print Dumper(@ill);
	print "------------------------------\n";
}

# add more metadata
for (my $i = 0; $i < scalar(@ill); ++$i) {
	$ill[$i]->{'imgFile'} = $gid2img{$alto2gid{$ill[$i]->{'altoid'}}};
	$ill[$i]->{'metsIdentifier'} = $id;
	$ill[$i]->{'metsPID'} = $pid;
	$ill[$i]->{'metsDate'} = $date;
	$ill[$i]->{'metsNumPages'} = $numpages;
	$ill[$i]->{'metsLabel'} = $label;
}

if ($debug > 1) {
	print "-------- @ill after pixel ----\n";
	print Dumper(@ill);
	print "------------------------------\n";
}

if ($debug > 0) {
	if ($id) {
		print "$id\t";
	}
	print "$label\t$date\n";

	foreach my $a (sort keys %alto2gid) {
		my $g = $alto2gid{$a};
		print $a."\t".$g."\t".$gid2alto{$g}."\t".$gid2img{$g}."\n";
	}
}

# create directory for output files
`mkdir -p $outputdir`;

# write the output files
for (my $i = 0; $i < scalar(@ill); ++$i) {
	my $fname = $pid."-".$ill[$i]->{'altoid'}."-".$ill[$i]->{'blockid'};
	if ($debug > 0) {
		print "$outputdir$fname.xml\n";
	}
	&outputAsXML($ill[$i], $outputdir.$fname.".xml");
}

# extract the images
my $cmdf = $outputdir."cmd";
open(FCMD, ">$cmdf") || die "cannot open command file\n";
print FCMD $cropcmd;
close(FCMD);
`fasttiffcrop < $cmdf`;
`rm $cmdf`;

sub extractDiv()
{
	my ($div) = @_;
	my $divType;
        my $label;
        if ($div =~ /<div/) {
	        if ($div =~ /<div .*TYPE="([^"]*)"/) {
                	$divType = $1;
                }
                if ($div =~ /<div .*LABEL="([^"]*)"/) {
                        $label = $1;
                }
	}
	return ($divType, $label);
}

sub readAlto()
{
	my ($fileid, $blks) = @_;
	shift;
	if (!defined $alto2gid{$fileid}) {
		die "ERROR - $pid - no alto file corresponding to $fileid\n";
	}
	my $fname = $gid2alto{$alto2gid{$fileid}};

	my @coordinates;
	my $p;
	open(AIN, $fname) || die "ERROR - $pid - cannot open ALTO file $fname\n";
	while (<AIN>) {
		if (/<Page .*/) {
			$p = &altoCoord($_);
		} elsif (/<([^\ ]*) .*ID="([^"]*)"/) {
			my $atype = $1;
			my $id = $2;
			my $line = $_;
			if (defined ${$blks}{$id}) {
				my $c = &altoCoord($line);
				${$c}{'ILLUSTRATION_ID'} = ${$blks}{$id};
				${$c}{'altoType'} = $atype;
				$c->{'pageWidth'} = $p->{'width'};
				$c->{'pageHeight'} = $p->{'height'};
				push @coordinates, $c;
			}
		}
	}
	close(AIN);
	return \@coordinates;
}

sub altoCoord()
{
	my ($line) = @_;
	my %res;
	if ($line =~ /HPOS="([^"]*)"/) {
		$res{'hpos'} = $1;
	}
	if ($line =~ /VPOS="([^"]*)"/) {
                $res{'vpos'} = $1;
        }
	if ($line =~ /HEIGHT="([^"]*)"/) {
                $res{'height'} = $1;
        }
	if ($line =~ /WIDTH="([^"]*)"/) {
                $res{'width'} = $1;
        }
	return \%res;
}

sub mm10toPixel()
{
	my ($a) = @_;
	return floor($a * 300 / 254);
}

sub outputAsXML()
{
	my ($ill, $fname) = @_;
	open(FOUT, ">$fname") || die "cannot open $fname for writing\n";
	print FOUT '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print FOUT "<img>\n";
	foreach my $k (sort keys %{$ill}) {
		
		print FOUT '  <'.$k.'>';
		if (defined $ill->{$k}) {
			if (ref($ill->{$k}) eq 'ARRAY') {
				for (my $v=0; $v < scalar(@{$ill->{$k}});++$v) {
					print FOUT '    <'.$k.' id='.$v.'>'.${$ill->{$k}}[$v].'</'.$k.">\n";
				}
			} else {
				print FOUT $ill->{$k};
			}
		}
		print FOUT '</'.$k.">\n";
	}
	print FOUT "</img>\n";
}

sub genCropCmd()
{
	my ($ill, $fname) = @_;
	my $res = "convert ";
	$res = $res."-crop ".$ill->{'width'}."x".$ill->{'height'}."+".$ill->{'hpos'}."+".$ill->{'vpos'};
	$res = $res." \"".$ill->{'imgFile'}."\" \"$fname\"";
	return $res;
}
