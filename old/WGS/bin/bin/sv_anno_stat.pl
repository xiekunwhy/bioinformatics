#!/usr/bin/perl -w
use strict;
use warnings;
my $BEGIN_TIME=time();
use Getopt::Long;
my ($fanno,$outfile,$Key);
use Data::Dumper;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
my $version="1.0.0";
GetOptions(
	"help|?" =>\&USAGE,
	"anno:s"=>\$fanno,
	"out:s"=>\$outfile,
	"key:s"=>\$Key,
			) or &USAGE;
&USAGE unless ($fanno and $outfile and $Key);
open In,$fanno;
my %stat;
while (<In>) {
	chomp;
	next if ($_ eq "" || /^$/ || /^#/);
	my ($chr1,$pos1,$chr2,$pos2,$length,$type,$pvalue,$gene,$genename)=split(/\t/,$_);
	 $stat{$type}{total}++;
	 if ($gene !=0) {
		 $stat{$type}{gene}++;
	 }
}
close In;
open Out,">$outfile";
print Out "$Key\tTotal\tGene";
foreach my $type (sort keys %stat) {
	$stat{$type}{gene}||=0;
	print Out $type,"\t",$stat{$type}{total},"\t",$stat{$type}{gene},"\n";
}
#######################################################################################
print STDOUT "\nDone. Total elapsed time : ",time()-$BEGIN_TIME,"s\n";
#######################################################################################
sub USAGE {#
        my $usage=<<"USAGE";
Contact:        long.huang\@majorbio.com;
Script:			$Script
Description:
	eg:
	perl $Script -i -o 

Usage:
  Options:
  -exonic	<file>	input file name
  -variant	<file>	input file name
  -outfile	<dir>	output dir
  -statfile	<stat>	output stat file
  -h         Help

USAGE
        print $usage;
        exit;
}