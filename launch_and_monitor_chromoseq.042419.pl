#!/usr/bin/perl

use strict;
use JSON;
use YAML::Tiny;
use Getopt::Long;

my $usage = "Usage: $0 -name <project-name> -out <outdir> <LIMS dir 1> [LIMS dir 2 ...]";

my $BS = '/usr/local/bin/bs';

my $DRAGENAPP = 6495489; #v3.2.8, ID taken from url: https://basespace.illumina.com/apps/6495489/DRAGEN-Somatic-Pipeline
my $CHROMOSEQAPP = 6984978; #V1.0.0, ID taken from url: https://basespace.illumina.com/apps/6984978/Chromoseq

my $RefId = 14321367413; #see README for the steps used to find this

my $debug = "";

my $ProjectName = "";
my $outdir = "";

GetOptions("d" => \$debug,
	   "name=s" => \$ProjectName,
	   "out=s" => \$outdir);

die $usage if !$ProjectName || !$outdir || scalar @ARGV < 1;

mkdir $outdir if !-e $outdir;
$outdir = `readlink -f $outdir`;
chomp $outdir;

my @dirs = @ARGV;

map { die "$_ doesnt exist" if ! -e $_ } @dirs;

# go through datasets and make sure they're all from the same library
my %datasets = ();

foreach my $dir (@dirs){ 
    # parse manifest.
    my $yaml = `ls $dir/*.yaml`;
    chomp $yaml;
    die "No metadata file found in $dir" if !$yaml;
    
    my $y = new YAML::Tiny;
    my %dat = %{($y->read($yaml))->[0]};

    my $name = $dat{library_summary}{full_name};
    $datasets{$name} = \%dat;
}

die "Multiple directories with different sample/library information detected!" if scalar keys %datasets > 1;

# get dataset info, make biosample, and upload
my %manifest = %{$datasets{(keys %datasets)[0]}};
my $biosamplename = $manifest{sample}{full_name};

$biosamplename = $biosamplename . "-DEBUG" if $debug;

$outdir = $outdir . '/' . $biosamplename;
mkdir $outdir if !-e $outdir;

# first check to see if biosample is present and create it if necessary
my $biosample_json = '';
my @biosample_check = `$BS list biosample -f csv`;
chomp @biosample_check;
my %biosamples = map { my @l = split(",",$_); $l[0] => $l[1] } @biosample_check[1..$#biosample_check];

die "Biosample $biosamplename is already on basespace. Exiting" if (defined($biosamples{$biosamplename}));
    
print STDERR "No samples called $biosamplename found. Creating it...\n";

my $metadata = join(" ",(map { "--metadata Sample.$_:$manifest{sample}{$_}" } keys %{$manifest{sample}}),
		    (map { "--metadata LibrarySummary.$_:$manifest{library_summary}{$_}" } keys %{$manifest{library_summary}}));

`$BS create biosample -n $biosamplename $manifest{library}{full_name} -p $ProjectName $metadata | tee $outdir/$biosamplename.$manifest{index_illumina}{analysis_id}.create_biosample.json`;

# for some reason it takes a few seconds for the new biosample to register
sleep 10;

my $biosample_json = from_json(`$BS biosample get -n $biosamplename -f json`);

# get project id
my $ProjectId = `bs project list --filter-term \"^$ProjectName\$\" --terse`;
chomp $ProjectId;

my $dirs = join(" ", @dirs);

my $label = "Upload $biosamplename " . localtime();
print STDERR "Uploading $biosamplename...\n";
`$BS upload dataset -p $ProjectId --recursive --biosample-name=$biosamplename --library-name=$manifest{library_summary}{full_name} -l \"$label\" $dirs`;

# added another sleep just to be safe
sleep 10;

$label = "Dragen $biosamplename " . localtime();
my $align_json = from_json(`$BS launch application -i $DRAGENAPP -o app-session-name:\"$label\" -o project-id:$ProjectId -o ht-ref:custom.v7 -o ht-id:$RefId -o input_list.tumor-sample:$biosample_json->{Id} -o dupmark_checkbox:1 -o bai_checkbox:1 -o output_format:CRAM -f json | tee $outdir/$biosamplename.$manifest{index_illumina}{analysis_id}.dragen.json`);

print STDERR "Launched Dragen: $label. Waiting...\n";

# now wait
my $align_result = from_json(`$BS await appsession $align_json->{Id} -f json`);

die "Dragen failed! Check logs for AppSession: $align_result->{AppSession}{Name}" if ($align_result->{AppSession}{ExecutionStatus} !~ /Complete/);

print STDERR "Dragen finished. Downloading QC data\n";

`$BS dataset download -i $align_result->{Id} --extension=csv -o $outdir`;

# get cram files, first by getting the appresult for the dragen process, then the file id from that process
my $appresultId = `$BS dataset get -i $align_result->{Id} -F V1pre3Id -f csv`;
chomp $appresultId;
$appresultId =~ s/[^0-9]+//g;

my @cram = `$BS appresult content -i $appresultId --extension=cram,crai --terse`;
chomp @cram;
my $files = join(",",@cram);

# launch chromoseq
$label = "Chromoseq $biosamplename " . localtime();
my $chromoseq_session = from_json(`$BS launch application -i $CHROMOSEQAPP -o app-session-name:\"$label\" -o project-id:$ProjectId -o file-id:$files -f json | tee $outdir/$biosamplename.$manifest{index_illumina}{analysis_id}.chromoseq.json`);

my $chromoseq_result = from_json(`$BS await appsession $chromoseq_session->{Id} -f json`);

print STDERR "Launched Chromoseq: $label. Waiting...\n";

die "Chromoseq failed! Check logs for AppSession: $chromoseq_result->{AppSession}{Name}" if ($chromoseq_result->{AppSession}{ExecutionStatus} !~ /Complete/);

print STDERR "Chromoseq finished.\nDownloading files to $outdir.\n";

# download files
`$BS download dataset -i $chromoseq_result->{Id} -o $outdir`;

print STDERR "Done.\n";
