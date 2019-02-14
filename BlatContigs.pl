#!/usr/bin/perl

use List::Util qw(min max);
use Getopt::Long;
use strict;

my $slop = 200;
my $PR = 2;
my $SR = 2;
my $junctionComp = .7;
my $junctionLength = 10;
my $contigComp = .35;
my $blatAligned = 20;
my $blatIdentity = 95;

my $REF = '';

GetOptions("slop=i" => \$slop,
	   "pr=i" => \$PR,
	   "sr=i" => \$SR,
	   "j=f" => \$junctionComp,
	   "c=f" => \$contigComp,
	   "a=i" => \$blatAligned,
	   "i=i" => \$blatIdentity,
	   "r=s" => \$REF);

die "no reference supplied" if !$REF;

my $out = $ARGV[1];

open(M,"zcat $ARGV[0] |") || die "Cant open manta file $ARGV[0]";

open(FA,">/tmp/input.fa") || die "cant make temporary fasta file";
my %seqs = ();
while(<M>){
    chomp;
    next if /^#/;
    my @F = split("\t",$_);

    # must have minimum PR and SR reads
    next unless $F[8] =~ /PR/ and $F[8] =~ /SR/;
    $F[9] =~ /(\d+),(\d+):(\d+),(\d+)/;
    next unless $2 > $PR and $4 > $SR;

    # if junction has low nucleotide complexity
    if ($F[4] =~ /([ACGT]+)[\[\]]|[\[\]]([ACGT]+)/){
	my $junc = $1;
	my %comp = ();
	map { $comp{$_}++ } split('',$junc);

	next if (length($junc) > $junctionLength && (max(values %comp)/length($junc)) > $junctionComp);
    }

    if ($F[7] =~ /CONTIG=([ACGTNactgn]+)/){
	my $contig = $1;
	# contigs can have a maximum of 35% of one base
	my %comp = ();
	map { $comp{$_}++ } split('',$contig);

	next if (max(values %comp)/length($contig)) > $contigComp;
	
	print FA ">$F[2]\n$contig\n";
	$seqs{$F[2]} = length($contig);
    }
}
close M;
close FA;

print STDERR "Done getting contigs. Now mapping...\n";

`/usr/local/bin/blat -fastMap -noHead $REF /tmp/input.fa /tmp/out.psl && /usr/bin/perl /usr/local/bin/pslScore.pl /tmp/out.psl > /tmp/map.out`;

my %map1 = ();
open(MAP,"/tmp/map.out");
while(<MAP>){
    chomp;
    my @F = split("\t",$_);

    # require a minimum percent identity of 95 and a minimum fraction aligned of 20%
    next unless $F[6] > $blatAligned && $F[8] > $blatIdentity;
    my $id = $F[3];
    $id =~ s/:\d+-\d+$//;
    push @{$map1{$id}}, [ $F[7], $F[0], $F[1], $F[2] ];
}
close MAP;

my %map = ();
foreach my $k (keys %map1){
#    print STDERR $k,"\t",(scalar @{$map1{$k}}),"\n";
    @{$map{$k}} = (sort { $b->[0] <=> $a->[0] } @{$map1{$k}})[0..1];
}

print STDERR "Done mapping. Finding hits...\n";

open(O,">$out") || die;

open(M,"zcat $ARGV[0] |") || die "Cant open manta file $ARGV[0]";
while(<M>){
    if (/^##FILTER/){
	do {
	    print O;
	    $_ = <M>;
	} while(/^##FILTER/);	
	print O '##FILTER=<ID=LowReads,Description="Failed minimum number of PR or SR reads">',"\n";
	print O '##FILTER=<ID=NoContig,Description="No contig">',"\n";
	print O '##FILTER=<ID=FailedBlat,Description="Blat of contig failed to reproduce breakends">',"\n";
	next;
    } elsif (/^#/){
	print O;
	next;
    }
    
    chomp;
    my @F = split("\t",$_);

    if ($F[8] !~ /PR/ or $F[8] !~ /SR/ or ($F[9] =~ /(\d+),(\d+):(\d+),(\d+)/ and ($2 < $PR or $4 < $SR))){
	$F[6] = "LowReads";
	
    } elsif ($F[7] !~ /CONTIG=/ or !defined($map{$F[2]})){
	$F[6] = "NoContig";
	
    } else {
	
	if ($F[2] =~ /DEL|INV|DUP|INS/){
	    $F[7] =~/END=(\d+)/;

	    my $chr1 = $F[0];
	    my $pos1 = $F[1];
	    my $chr2 = $F[0];
	    my $pos2 = $1;

	    my $one = 0;
	    foreach my $i (@{$map{$F[2]}}){
		$one = 1 if ($i->[0] eq $chr1 && abs($pos1 - $i->[1]) < $slop);
	    }
	    my $two = 0;
	    foreach my $i (@{$map{$F[2]}}){
		$two = 1 if ($i->[0] eq $chr2 && abs($pos2 - $i->[1]) < $slop);
	    }

	    if ($one > 0 and $two > 0){
		$F[6] = "PASS";
	    } else {
		$F[6] = "FailedBlat";
	    }
	    
	} elsif ($F[2] =~ /BND/) {
	    $F[4] =~/(chr\S+):(\d+)/;

	    my $chr1 = $F[0];
	    my $pos1 = $F[1];
	    my $chr2 = $1;
	    my $pos2 = $2;

	    my $one = 0;
	    foreach my $i (@{$map{$F[2]}}){
		$one = 1 if ($i->[1] eq $chr1 && abs($pos1 - $i->[2]) < $slop);
	    }
	    my $two = 0;
	    foreach my $i (@{$map{$F[2]}}){
		$two = 1 if ($i->[1] eq $chr2 && abs($pos2 - $i->[2]) < $slop);
	    }

	    if ($one > 0 and $two > 0){
		$F[6] = "PASS";
	    } else {
		$F[6] = "FailedBlat";
	    }
	}
    }
    print O join("\t",@F),"\n";
}
close M;
close O;
