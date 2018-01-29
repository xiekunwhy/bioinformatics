#!/usr/bin/env perl 
use strict;
use warnings;
use Getopt::Long;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
use Data::Dumper;
my $BEGIN_TIME=time();
my $version="1.0.0";
#######################################################################################

# ------------------------------------------------------------------
# GetOptions
# ------------------------------------------------------------------
my ($fIn,$fOut,$PID,$BID,$Pdep,$Bdep);
GetOptions(
				"help|?" =>\&USAGE,
				"vcf:s"=>\$fIn,
				"out:s"=>\$fOut,
				"pid:s"=>\$PID,
				"bid:s"=>\$BID,
				"pdep:s"=>\$Pdep,
				"Bdep:s"=>\$Bdep,
				) or &USAGE;
&USAGE unless ($fIn and $fOut and $BID);
$Pdep||=10;
$Bdep||=10;
$PID||="";
my %Indi;
if ($PID ne "") {
	my ($P1,$P2)=split(/\,/,$PID);
	$P2||=$P1;
	$Indi{$P1}="P1";
	if ($P1 ne $P2) {
		$Indi{$P2}="P2";
	}
}
$Indi{$BID}="B";
if ($fIn =~ /gz$/) {
	open In,"gunzip -dc $fIn|";
}else{
	open In,$fIn;
}
open Out,">$fOut.index";
open Variant,">$fOut.variant";
my @indi;
my %stat;
while (<In>) {
	chomp;
	next if ($_ eq ""||/^$/ ||/^##/);
	my ($chr,$pos,$ids,$ref,$alt,$qual,$filter,$info,$format,@geno)=split(/\s+/,$_);
	if (/^#/) {
		push @indi,@geno;
		my @out;
		foreach my $indi (@geno) {
			next if (!exists $Indi{$indi});
			push @out,$indi."-GT";
			push @out,$indi."-AD";
		}
		print Out join("\t","#chr","pos","type","ref",@out,"index","ANNOTATION","HIGH","MODERATE","LOW","MODIFIER"),"\n";
		print Variant join("\t","#chr","type","pos","ref",@out,"ANNOTATION"),"\n";

	}else{
		my %info;
		my @alle=split(",",join(",",$ref,$alt));
		my %len;
		for (my $i=0;$i<@alle;$i++) {
			$len{length($alle[$i])}=1;
		}
		my $type="SNP";
		if (scalar keys %len > 1) {
			$type="INDEL";
		}

		my @format=split(/:/,$format);
		my %ginfo;
		my @outvariant;
		for (my $i=0;$i<@indi;$i++) {
			next if (!exists $Indi{$indi[$i]});
			my @gt=split(/\//,$geno[$i]);
			my $id=$Indi{$indi[$i]};
			my @info=split(/:/,$geno[$i]);
			for (my $j=0;$j<@info;$j++) {
				$info{$id}{gt}=$info[$j] if ($format[$j] eq "GT");
				$info{$id}{ad}=$info[$j] if ($format[$j] eq "AD");
				$info{$id}{dp}=$info[$j] if ($format[$j] eq "DP");
			}
			if ($info{$id}{gt} eq "./.") {
				$ginfo{$indi[$i]}{gt}="--";
				$ginfo{$indi[$i]}{ad}="0";
			}else{
				my ($g1,$g2)=split(/\//,$info{$id}{gt});
				my @ad=split(/\,/,$info{$id}{ad});
				$ginfo{$indi[$i]}{gt}=join("/",$alle[$g1],$alle[$g2]);
				if ($g1 eq $g2) {
					$ginfo{$indi[$i]}{ad}=$ad[$g1];
				}else{
					$ginfo{$indi[$i]}{ad}=join(",",$ad[$g1],$ad[$g2]);
				}
			}
			push @outvariant,$ginfo{$indi[$i]}{gt};
			push @outvariant,$ginfo{$indi[$i]}{ad};
		}
		my @out;
		my %ann;
		if($info=~/ANN=([^\;]*)/g){
			my @ann=split(/\,/,$1);
			for (my $i=0;$i<@ann;$i++) {
				my @str=split(/\|/,$ann[$i]);
				my $ann=join("|",$str[1],$str[2],$str[3],$str[4]);
				$ann{$str[2]}++;
				push @out,$ann;
			}
		}
		$ann{HIGH}||=0;
		$ann{MODERATE}||=0;
		$ann{LOW}||=0;
		$ann{MODIFIER}||=0;
		if (scalar @out ==0) {
			print Variant join("\t",$chr,$pos,$type,"$ref"."$ref",@outvariant,"--",$ann{HIGH},$ann{MODERATE},$ann{LOW},$ann{MODIFIER}),"\n";
		}else{
			print Variant join("\t",$chr,$pos,$type,"$ref"."$ref",@outvariant,join(";",@out),$ann{HIGH},$ann{MODERATE},$ann{LOW},$ann{MODIFIER}),"\n";
		}
		if (!exists $info{P1}) {
			$info{P1}{gt}="0/0";
			$info{P1}{dp}="10";
			$info{P1}{ad}="10,0";
		}
		next if ($info{P1}{gt} eq "./." || $info{B}{gt} eq "./.");
		next if ($info{P1}{gt} eq $info{B}{gt});
		next if ($info{P1}{dp} < $Pdep || $info{B}{dp} < $Bdep);
		my ($p1,$p2)=split(/\/|\|/,$info{P1}{gt});
		my ($b1,$b2)=split(/\/|\|/,$info{B}{gt});
		next if ($p1 ne $p2);
		next if ($p1 ne $b1 && $p1 ne $b2 && $b1 ne $b2);
		my $mut=$b1;
		if ($p1 == $b1) {
			$mut=$b2;
		}
		if (exists $info{P2} && exists $info{P1} ) {
			my ($p3,$p4)=split(/\/|\|/,$info{P2}{gt});
			next if ($p3 ne $p4);
			next if ($info{P1}{gt} ne $info{P2}{gt});
			next if($p3 ne $b1 && $p3 ne $b2);
			$mut=$p3;
		}
		my @dp=split(/\,/,$info{B}{ad});
		my $sum=0;
		if ($b1 eq $b2) {
			$sum=$dp[$b1];
		}else{
			$sum=$dp[$b1]+$dp[$b2];
		}
		my $snpindex=$dp[$mut]/$sum;
		$info{P1}{gt}||="--";
		$info{P1}{ad}||="--";
		$info{B}{gt}||="--";
		$info{B}{ad}||="--";
		my $lchr=$chr;
		if ($lchr !~ /chr/) {
			$lchr = "scaffords";
		}
		$stat{$lchr}{$type}++;
		
		if (scalar @out ==0) {
			print Out join("\t",$chr,$pos,$type,"$ref/"."$ref",@outvariant,$snpindex,"--",$ann{HIGH},$ann{MODERATE},$ann{LOW},$ann{MODIFIER}),"\n";
		}else{
			print Out join("\t",$chr,$pos,$type,"$ref/"."$ref",@outvariant,$snpindex,join(";",@out),$ann{HIGH},$ann{MODERATE},$ann{LOW},$ann{MODIFIER}),"\n";
		}
	}
}
close In;
close Out;
open Out,">$fOut.stat";
print Out "#chr\tsnp\tindel\n";
foreach my $chr (sort keys %stat) {
	$stat{$chr}{SNP}||=0;
	$stat{$chr}{InDel}||=0;
	print Out join("\t",$chr,$stat{$chr}{SNP},$stat{$chr}{InDel}),"\n";
}
close Out;

#######################################################################################
print "\nDone. Total elapsed time : ",time()-$BEGIN_TIME,"s\n";
#######################################################################################

sub USAGE {#
	my $usage=<<"USAGE";
Description: 
Version:  $Script
Contact: long.huang

Usage:
  Options:
	-vcf	<file>	input file 
	-out	<file>	output file
	-pid	<str>	wild parent id may not
	-bid	<str>	mut bulk id
	-pdep	<str>	parent depth default 10
	-bdep	<str>	mut build depth default 10
USAGE
	print $usage;
	exit;
}
