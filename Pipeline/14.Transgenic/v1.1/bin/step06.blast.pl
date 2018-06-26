#!/usr/bin/perl -w
use strict;
use warnings;
my $BEGIN_TIME=time();
use Getopt::Long;
my ($list,$dsh,$out,$db);
use Data::Dumper;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
my $version="1.0.0";
GetOptions(
	"help|?" =>\&USAGE,
	"list:s"=>\$list,
    "db:s"=>\$db,
    "dsh:s"=>\$dsh,
    "out:s"=>\$out,
			) or &USAGE;
&USAGE unless ($list and $db and $out and $dsh);
mkdir $out if (!-d $out);
mkdir $dsh if (!-d $dsh);
$list=ABSOLUTE_DIR($list);
$out=ABSOLUTE_DIR($out);
$dsh=ABSOLUTE_DIR($dsh);

open SH,">$dsh/step05.blast.sh";
open IN,"$list";
while(<IN>){
    $_=~s/[\n\r]//g;
    my ($id,$soap)=split/\t/,$_;
    print SH "blastn -query $soap -out $out/$id.blast -db $db -outfmt 6 -evalue 1e-5 -num_threads 8\n";
    }
close SH;
close IN;
my $job="perl /mnt/ilustre/users/dna/.env//bin//qsub-sge.pl --CPU 8 --Resource mem=5G $dsh/step05.blast.sh";
`$job`;

#######################################################################################
print STDOUT "\nDone. Total elapsed time : ",time()-$BEGIN_TIME,"s\n";
#######################################################################################
sub ABSOLUTE_DIR {#
	my $cur_dir=`pwd`;chomp($cur_dir);
	my ($in)=@_;
	my $return="";
	if(-f $in){
		my $dir=dirname($in);
		my $file=basename($in);
		chdir $dir;$dir=`pwd`;chomp $dir;
		$return="$dir/$file";
	}elsif(-d $in){
		chdir $in;$return=`pwd`;chomp $return;
	}else{
		warn "Warning just for file and dir \n$in";
		exit;
	}
	chdir $cur_dir;
	return $return;
}

sub USAGE {#
        my $usage=<<"USAGE";
Contact:        nanshan.yang\@majorbio.com;
Script:			$Script
Description:
	
	eg:
	perl $Script 

Usage:
  Options:
  -list  <file> soap denovo fq list 
  -db   <file>  blast dbname file 
  -out	<dir>	output dir
  -dsh	<dir>	output work shell

  -h         Help

USAGE
        print $usage;
        exit;
}
