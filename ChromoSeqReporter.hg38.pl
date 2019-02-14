#!/usr/bin/perl

use strict;
use JSON;

sub lookup_bed {
    my ($c,$p,$h) = @_;
    my @ret = ();
    foreach my $k (keys %{$h}){
	if ($c eq $h->{$k}{chr} and $p > $h->{$k}{start} and $p < $h->{$k}{end}){
	    push @ret, $h->{$k};
	}
    }
    @ret;
}

sub lookup_translocation {
    my ($c1,$p1,$c2,$p2,$slop,$h) = @_;

    my @ret = ();
    foreach my $k (keys %{$h}){
	if ($c1 eq $h->{$k}{chr1} and $p1 > ($h->{$k}{start1} - $slop) and $p1 < ($h->{$k}{end1} + $slop)
	    and $c2 eq $h->{$k}{chr2} and $p2 > ($h->{$k}{start2} - $slop) and $p2 < ($h->{$k}{end2} + $slop)){
	    push @ret, $h->{$k};
	} elsif ($c1 eq $h->{$k}{chr1} and $p1 > ($h->{$k}{start1} - $slop) and $p1 < ($h->{$k}{end1} + $slop) and $h->{$k}{chr2} eq '0'){
	    push @ret, $h->{$k};
	}	    
    }
    @ret;      
}
    
my $CNVBED = "/opt/files/ChromoSeq.hg38.bed";
my $TRANSBED = "/opt/files/ChromoSeq.translocations.fixed.v2.sorted.hg38.bedpe";

my $slop = 0;
my $frac_for_whole_del = 0.75;

my %genelist = ();

my ($name,$variants,$cnvs,$translocations) =  @ARGV;

print "ChromoSeq Report for $name ---- Generated on: " . localtime() . "\n\n";

my %arms = ();
my %chroms = ();
open(BED,$CNVBED) || die;
while(<BED>){
    chomp;
    my @l = split("\t",$_);
    $arms{$l[4]}++;
    $chroms{$l[0]}{$l[3]} = 1;
    
    $genelist{$l[5]}++ if $l[5] ne '.';
    
}
close BED;

print "Copy number alterations:\n\n";

my $anycnvs = 0;

open(F,$cnvs) || die "cant open file: $cnvs";
my $gender = <F>;
chomp $gender;

while(<F>){
    chomp;
    my ($chr,$start,$end,$segs,$l2r,$cn,$change,$bands,$band_count,$arms,$arm_count,$genes) = split("\t",$_);

    next if ($gender eq 'male' and $chr eq 'chrX' and $segs > 150 and $change eq 'HETD');
    
    my $c = $chr;
    $c =~ s/chr//g;
    
    $genes =~ s/^\.,|\.//g;

    if ($change eq 'GAIN'){
	# whole chromosome
	if ($band_count > (scalar(keys %{$chroms{$chr}}) * $frac_for_whole_del)){
	    print "+" . $c . "\t[ " . "ploidy: $cn, " . "est. abundance: " . sprintf("%.1f\%",((2**$l2r - 1) / (($cn/2 - 1)))*100) . ", Genes affected: " . $genes . " ]\n";
	   	    
	} else {
	    my @bands = split(",",$bands);
	    print "+" . $c . $bands[0] . '-' . $bands[$#bands] . "\t[ " . "ploidy: $cn, " . "est. abundance: " . sprintf("%.1f\%",((2**$l2r - 1) / (($cn/2 - 1)))*100) . ", Genes affected: " . $genes . " ]\n";

	}
    } elsif ($change eq 'HETD'){
	# whole chromosome
	if ($band_count > (scalar(keys %{$chroms{$chr}}) * $frac_for_whole_del)){
	    print "-" . $c . "\t[ " . "ploidy: $cn, " . "est. abundance: " . sprintf("%.1f\%",((2**$l2r - 1) / (($cn/2 - 1)))*100) . ", Genes affected: " . $genes . " ]\n";

	} else {
	    my @bands = split(",",$bands);
	    print "del(" . $c . $bands[0] . '-' . $bands[$#bands] . ")\t[ " . "ploidy: $cn, " . "est. abundance: " . sprintf("%.1f\%",((2**$l2r - 1) / (($cn/2 - 1)))*100) . ", Genes affected: " . $genes . " ]\n";
	    
	}
    }
    $anycnvs++;
}
close F;

if ($anycnvs == 0){
    print "***NO COPY NUMBER CHANGES IDENTIFIED***\n\n";
} else {
    print "\n\n";
}

print "Known Translocations:\n\n";

my %bands = ();
open(BED,$CNVBED) || die;
while(<BED>){
    chomp;
    my @l = split("\t",$_);
    $bands{"$l[0]:$l[1]-$l[2]"} = { chr => $l[0],
		      start => $l[1],
		      end => $l[2],
		      band => $l[3],
		      arm => $l[4] };
}
close BED;

my %trans = ();
open(BED,$TRANSBED) || die;
while(<BED>){
    chomp;
    my @l = split("\t",$_);
    $trans{$l[6]} = { chr1 => $l[0],
		      start1 => $l[1],
		      end1 => $l[2],
		      chr2 => $l[3],
		      start2 => $l[4],
		      end2 => $l[5],
		      band1 => $l[7],
		      band2 => $l[8],
		      genes => $l[6]};
    my ($g1,$g2) = split("_",$l[6]);

    $genelist{$g1}++;
    $genelist{$g2}++;
    
}
close BED;

my $anytrans = 0;

my %t2 = ();
    
open(T,"gunzip -c $translocations |") || die;
while(<T>){
    next if /^#/;
    chomp;
    my @l = split("\t",$_);

    my $foundtrans = 0;
    
    my ($chr1,$pos1,$chr2,$pos2,$type);
    
    if (/SVTYPE=BND/){
	$type = "translocation";
	($chr1,$pos1) = @l[0..1];
	$l[4] =~ /[\[\]](\S+):(\d+)[\[\]]/;
	$chr2 = $1;
	$pos2 = $2;

	my @t = lookup_translocation($chr1,$pos1,$chr2,$pos2,$slop,\%trans);
	if (scalar @t > 0){
	    
	    my @p1 = lookup_bed($chr1,$pos1,\%bands);
	    my @p2 = lookup_bed($chr2,$pos2,\%bands);
	    
	    # get support
	    my @format = split(":",$l[9]);
	    
	    $l[9] =~ /^(\d+),(\d+)/;
	    my $paired_support = "$2/" . ($1+$2);
	    my $paired_fraction = $2/($2+$1);
	    
	    my $split_support = '';
	    my $split_fraction = '';
	    if ($l[9] =~ /:(\d+),(\d+)$/){
		$split_support = "$2/" . ($1+$2);
		$split_fraction = $2/($2+$1);
	    }
	    
	    my $ci = '';
	    if ($l[7] =~ /CIPOS=(\S+?);/){
		$ci = "PRECISION: $1";
	    }
	    $l[7] =~ /[^_=]BND_DEPTH=(\d+)/;
	    my $dp1 = $1;
	    $l[7] =~ /MATE_BND_DEPTH=(\d+)/;
	    my $dp2 = $1;	
	    
	    foreach my $t (@t){
		my $c1 = $chr1;
		$c1 =~ s/chr//;
		my $c2 = $chr2;
		$c2 =~ s/chr//;
		my ($gene1,$gene2) = split("_",$t->{genes});    
		print join("\t","t(" . $c1 . $p1[0]->{band} . ";" . $c2 . $p2[0]->{band} . ")",
			   "$gene1--$gene2","$chr1:$pos1;$chr2:$pos2",
			   "PAIRED_READS: $paired_support (" . sprintf("%.1f\%",$paired_fraction*100) . ")",
			   "SPLIT_READS: $split_support (" . sprintf("%.1f\%",$split_fraction*100) . ")",
			   "POS1 DEPTH: $dp1","POS2 DEPTH: $dp2",
			   $ci),"\n";
	    $foundtrans=1;
	    }
	    $anytrans++;
	}
    }
    
    # if not a recurrent translocation, then check quality and report as secondary finding
    if ($foundtrans == 0 && $l[6] eq 'PASS'){
	$l[2] =~ /(\S+):\d+$/;
	my $n = $1;
	my $chr1 = $l[0];
	my $pos1 = $l[1];
	my $chr2 = '';
	my $pos2 = '';

	my $type = '';
	
	if ($l[2] =~ /BND/){
	    $type = "BND";
	    $l[4] =~ /[\[\]](\S+):(\d+)[\[\]]/;
	    $chr2 = $1;
	    $pos2 = $2;
	} elsif ($l[2] =~ /(DEL|DUP|INS)/){
	    $type = $1;
	    $l[7]=~/END=(\d+)/;
	    $chr2 = $chr1;
	    $pos2 = $1;
	}
	
	# get support
	my @format = split(":",$l[9]);
	
	$l[9] =~ /^(\d+),(\d+):(\d+),(\d+)/;
	my $pref = $1;
	my $palt = $2;
	my $sref = $3;
	my $salt = $4;
	
	$l[7] =~ /CIPOS=(\S+?);/;
	my $ci = $1;
	$l[7] =~ /[^_=]BND_DEPTH=(\d+)/;
	my $dp1 = $1;
	$l[7] =~ /MATE_BND_DEPTH=(\d+)/;
	my $dp2 = $1;
	
	my @p1 = lookup_bed($chr1,$pos1,\%bands);
	$l[7] =~ /CSQ=(\S+)$/;
	my @a = split(",",$1);
	my @b = split /\|/, $a[0];
	my $g = $b[3];
	my $consequence = $b[1];
	my $exon = $b[8];
	my $intron = $b[9];	
	push @{$t2{$n}}, [ $chr1, $pos1, $p1[0]->{band}, $type, $g, $consequence, $exon, $intron, $pref, $palt, $sref, $salt, $ci, $dp1, $dp2 ];
    }
}

if ($anytrans == 0){
    print "***NO TRANSLOCATIONS IDENTIFIED***\n\n" 
} else {
    print "\n\n";
}


print "Gene-level hotspot analysis\n\n";


my @out = ();
open(F,$variants) || die;
<F>;
while(<F>){
    chomp;
    my @F = split("\t",$_);

    next if $F[10]=~/synonymous|UTR|stream/ || $F[5] eq 'FilteredInAll';
    $F[14]=~s/\S+:(c\.\S+?)/\1/g; 
    $F[15]=~s/\S+:(p\.\S+?)/\1/g; 
    $F[10]=~/^(\S+?)_/; 
    my $var=uc($1); 
    $var .= " INSERTION" if length($F[4])>length($F[3]); 
    $var .= " DELETION" if length($F[4])<length($F[3]);
    $var .= " SITE VARIANT" if $var =~ /SPLICE/;
    #    $F[15]=~s/\/\d+//g;
    push @out, join("\t",$F[11],uc($var),$F[15],$F[14],sprintf("%d%",$F[9]*100),$F[0],$F[1],$F[3],$F[4]); 
}
close F;

if (scalar @out > 0){
    print join("\t",qw(GENE VARIANT HGVSp HGVSc VAF CHROM POS REF ALT)),"\n", join("\n",@out),"\n";
} else {
    print "***NO GENE-LEVEL VARIANTS IDENTIFIED***\n\n";
}


#
# unknown SVs that pass muster
#

my @list1 = ();
my @list2 = ();    

map { 
  (scalar @{$t2{$_}} == 2 and ($genelist{$t2{$_}->[0][4]}>1 or $genelist{$t2{$_}->[1][4]}>1)) ? 
    push @list1, $_ : push @list2, $_ } (sort { $t2{$a}->[0][0] cmp $t2{$b}->[0][0] } keys %t2);

if (scalar (@list1) > 0){
  print "\n\nOther structural variants that involve known genes\n\n";
  
} elsif (scalar (@list2) > 0) {
  print "\n\nOther findings\n\n";

} else {
  print "No other findings identified\n\n";
  exit;
}

my @list = (@list1,"space",@list2);

foreach my $v (@list){
  
  if ($v eq 'space' and scalar @list2 > 0){
    print "\n\nOther findings\n\n";
    next;
  }
  
  my ($chr1,$pos1,$b1,$type1,$g1,$consequence1,$exon1,$intron1,$pref1,$palt1,$sref1,$salt1,$ci1,$dp11,$dp12) = @{$t2{$v}->[0]};
  my ($chr2,$pos2,$b2,$type2,$g2,$consequence2,$exon2,$intron2,$pref2,$palt2,$sref2,$salt2,$ci2,$dp21,$dp22) = @{$t2{$v}->[1]};
  my $paired_support = sprintf("%d",($palt1 + $palt2) / 2);
  my $paired_fraction = ($palt1 + $palt2) / ($palt1 + $pref1 + $palt2 + $pref2);
  my $split_support = sprintf("%d",($salt1 + $salt2) / 2);
  my $split_fraction = ($salt1 + $salt2) / ($salt1 + $sref1 + $salt2 + $sref2);
  my $ci = sprintf("%.1f",($ci1 + $ci2) / 2);
  my $dp1 = sprintf("%d",($dp11 + $dp22) / 2);
  my $dp2 = sprintf("%d",($dp12 + $dp21) / 2);
  
  $exon1 = "exon $1" if ($exon1 =~ /(\d+)\/\d+/);
  $exon2 = "exon $1" if ($exon2 =~ /(\d+)\/\d+/);    
  $intron1 = "intron $1" if ($intron1 =~ /(\d+)\/\d+/);
  $intron2 = "intron $1" if ($intron2 =~ /(\d+)\/\d+/);
  
  if ($consequence1 =~ /intergenic/){
    $consequence1 = "INTERGENIC";
  } elsif ($consequence1 =~ /stream/) {
    $consequence1 = "$g1($consequence1)";
    } else {
      $consequence1 = "$g1($exon1$intron1)";
    }
  
  if ($consequence2 =~ /intergenic/){
    $consequence2 = "INTERGENIC";
  } elsif ($consequence2 =~ /stream/) {
    $consequence2 = "$g2($consequence2)";
  } else {
    $consequence2 = "$g2($exon2$intron2)";
  }
    
  if ($type1 eq 'BND'){

    print join("\t","t(" . ($chr1=~/chr(\S+)/)[0] . $b1 . ";" . ($chr2=~/chr(\S+)/)[0] . $b2 . ")",
	       "$consequence1--$consequence2","$chr1:$pos1;$chr2:$pos2",
	       "PAIRED_READS: $paired_support (" . sprintf("%.1f\%",$paired_fraction*100) . ")",
	       "SPLIT_READS: $split_support (" . sprintf("%.1f\%",$split_fraction*100) . ")",
	       "POS1 DEPTH: $dp1","POS2 DEPTH: $dp2"),"\n";
  } else {
    
    print join("\t",lc($type1) . "(" . $chr1 . $b1 . "-" . $chr2 . $b2 . ")",
	       "$g1($exon1$intron1, $consequence1)--$g2($exon2$intron2, $consequence2)","$chr1:$pos1;$chr2:$pos2",
	       "PAIRED_READS: $paired_support (" . sprintf("%.1f\%",$paired_fraction*100) . ")",
	       "SPLIT_READS: $split_support (" . sprintf("%.1f\%",$split_fraction*100) . ")",
	       "POS1 DEPTH: $dp1","POS2 DEPTH: $dp2"),"\n";    
  }
}
