FROM ubuntu:xenial
MAINTAINER David H. Spencer <dspencer@wustl.edu>

LABEL description="Heavy container for Chromoseq"

RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    LC_ALL=en_US.UTF-8 && \
    LANG=en_US.UTF-8 && \
    /usr/sbin/update-locale LANG=en_US.UTF-8 && \
    TERM=xterm

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    build-essential \
    bzip2 \
    curl \
    default-jdk \
    default-jre \
    g++ \
    git \
    less \
    libcurl4-openssl-dev \
    libpng-dev \
    libssl-dev \
    libxml2-dev \
    make \
    ncurses-dev \
    nodejs \
    pkg-config \
    python \
    unzip \
    wget \
    zip \
    libbz2-dev \
    ca-certificates \
    file \
    fonts-texgyre \
    g++ \
    gfortran \
    gsfonts \
    libbz2-1.0 \
    libcurl3 \
    libicu55 \
    libjpeg-turbo8 \
    libopenblas-dev \
    libpangocairo-1.0-0 \
    libpcre3 \
    libpng12-0 \
    libtiff5 \
    liblzma5 \
    locales \
    zlib1g \
    libbz2-dev \
    libcairo2-dev \
    libcurl4-openssl-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libicu-dev \
    libpcre3-dev \
    libpng-dev \
    libreadline-dev \
    libtiff5-dev \
    liblzma-dev \
    libx11-dev \
    libxt-dev \
    perl \
    x11proto-core-dev \
    xauth \
    xfonts-base \
    xvfb \
    zlib1g-dev \
    bc \
    libnss-sss


##############
#HTSlib 1.9#
##############
ENV HTSLIB_INSTALL_DIR=/opt/htslib

WORKDIR /tmp
RUN wget https://github.com/samtools/htslib/releases/download/1.9/htslib-1.9.tar.bz2 && \
    tar --bzip2 -xvf htslib-1.9.tar.bz2 && \
    cd /tmp/htslib-1.9 && \
    ./configure --enable-plugins --prefix=$HTSLIB_INSTALL_DIR && \
    make && \
    make install && \
    cp $HTSLIB_INSTALL_DIR/lib/libhts.so* /usr/lib/ && \
    ln -s $HTSLIB_INSTALL_DIR/bin/tabix /usr/bin/tabix

################
#Samtools 1.9#
################
ENV SAMTOOLS_INSTALL_DIR=/opt/samtools

WORKDIR /tmp
RUN wget https://github.com/samtools/samtools/releases/download/1.9/samtools-1.9.tar.bz2 && \
    tar --bzip2 -xf samtools-1.9.tar.bz2 && \
    cd /tmp/samtools-1.9 && \
    ./configure --with-htslib=$HTSLIB_INSTALL_DIR --prefix=$SAMTOOLS_INSTALL_DIR && \
    make && \
    make install && \
    ln -s /opt/samtools/bin/* /usr/local/bin/ && \
    cd / && \
    rm -rf /tmp/samtools-1.9


##############
## bedtools ##

WORKDIR /usr/local
RUN git clone https://github.com/arq5x/bedtools2.git && \
    cd /usr/local/bedtools2 && \
    git checkout v2.27.0 && \
    make && \
    ln -s /usr/local/bedtools2/bin/* /usr/local/bin/

############################
# R, bioconductor packages #
ARG R_VERSION
ENV R_VERSION=${R_VERSION:-3.6.0}
RUN cd /tmp/ && \
    ## Download source code
    curl -O https://cran.r-project.org/src/base/R-3/R-${R_VERSION}.tar.gz && \
    ## Extract source code
    tar -xf R-${R_VERSION}.tar.gz && \
    cd R-${R_VERSION} && \
    ## Set compiler flags
    R_PAPERSIZE=letter && \
    R_BATCHSAVE="--no-save --no-restore" && \
    R_BROWSER=xdg-open && \
    PAGER=/usr/bin/pager && \
    PERL=/usr/bin/perl && \
    R_UNZIPCMD=/usr/bin/unzip && \
    R_ZIPCMD=/usr/bin/zip && \
    R_PRINTCMD=/usr/bin/lpr && \
    LIBnn=lib && \
    AWK=/usr/bin/awk && \
    CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" && \
    CXXFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" && \
    ## Configure options
    ./configure --enable-R-shlib \
               --enable-memory-profiling \
               --with-readline \
               --with-blas="-lopenblas" \
               --disable-nls \
               --without-recommended-packages && \
    ## Build and install
    make && \
    make install && \
    ## Add a default CRAN mirror
    echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site && \
    ## Add a library directory (for user-installed packages)
    mkdir -p /usr/local/lib/R/site-library && \
    chown root:staff /usr/local/lib/R/site-library && \
    chmod g+wx /usr/local/lib/R/site-library && \
    ## Fix library path
    echo "R_LIBS_USER='/usr/local/lib/R/site-library'" >> /usr/local/lib/R/etc/Renviron && \
    echo "R_LIBS=\${R_LIBS-'/usr/local/lib/R/site-library:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /usr/local/lib/R/etc/Renviron
   
##########################################
# Install conda and all python stuff
##########################################

# Configure environment
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH

RUN cd /tmp && \
    mkdir -p $CONDA_DIR && \
    curl -s https://repo.continuum.io/miniconda/Miniconda3-4.3.21-Linux-x86_64.sh -o miniconda.sh && \
    /bin/bash miniconda.sh -f -b -p $CONDA_DIR && \
    rm miniconda.sh && \
    $CONDA_DIR/bin/conda config --system --add channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    conda clean -tipsy

RUN conda config --add channels bioconda && \
    conda install -c conda-forge petl && \
    conda install -c anaconda biopython && \
    conda install -c anaconda scipy && \
    conda install -y -c bioconda mosdepth

RUN cd /tmp && git clone https://github.com/pysam-developers/pysam.git && \
    cd pysam && \
    export HTSLIB_LIBRARY_DIR=$HTSLIB_INSTALL_DIR/lib && \
    export HTSLIB_INCLUDE_DIR=$HTSLIB_INSTALL_DIR/include && \
    python setup.py install

# Install Python 2 
RUN conda create --quiet --yes -p $CONDA_DIR/envs/python2 python=2.7 'pip' && \
    conda clean -tipsy && \
    /bin/bash -c "source activate python2 && \
    conda install -c bioconda svtools && \
    source deactivate"

#
#  install manta
#
ENV manta_version 1.5.0
WORKDIR /opt/
RUN wget https://github.com/Illumina/manta/releases/download/v${manta_version}/manta-${manta_version}.centos6_x86_64.tar.bz2 && \
    tar -jxvf manta-${manta_version}.centos6_x86_64.tar.bz2 && \
    mv manta-${manta_version}.centos6_x86_64 /usr/local/src/manta

       
ENV VARSCAN_INSTALL_DIR=/opt/varscan

WORKDIR $VARSCAN_INSTALL_DIR
RUN wget https://github.com/dkoboldt/varscan/releases/download/2.4.2/VarScan.v2.4.2.jar && \
  ln -s VarScan.v2.4.2.jar VarScan.jar

#
# pindel
#

WORKDIR /opt
RUN wget https://github.com/genome/pindel/archive/v0.2.5b8.tar.gz && \
  tar -xzf v0.2.5b8.tar.gz

WORKDIR /opt/pindel-0.2.5b8
RUN ./INSTALL $HTSLIB_INSTALL_DIR

WORKDIR /
RUN ln -s /opt/pindel-0.2.5b8/pindel /usr/local/bin/pindel && \
    ln -s /opt/pindel-0.2.5b8/pindel2vcf /usr/local/bin/pindel2vcf


#
# GATK
#

#GATK 3.6#
ENV maven_package_name apache-maven-3.3.9
ENV gatk_dir_name gatk-protected
ENV gatk_version 3.6
RUN cd /tmp/ && wget -q http://mirror.nohup.it/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.zip

# LSF: Comment out the oracle.jrockit.jfr.StringConstantPool.
RUN cd /tmp/ \
    && git clone --recursive https://github.com/broadgsa/gatk-protected.git \
    && cd /tmp/gatk-protected && git checkout tags/${gatk_version} \
    && sed -i 's/^import oracle.jrockit.jfr.StringConstantPool;/\/\/import oracle.jrockit.jfr.StringConstantPool;/' ./public/gatk-tools-public/src/main/java/org/broadinstitute/gatk/tools/walkers/varianteval/VariantEval.java \
    && mv /tmp/gatk-protected /opt/${gatk_dir_name}-${gatk_version}
RUN cd /opt/ && unzip /tmp/${maven_package_name}-bin.zip \
    && rm -rf /tmp/${maven_package_name}-bin.zip LICENSE NOTICE README.txt \
    && cd /opt/ \
    && cd /opt/${gatk_dir_name}-${gatk_version} && /opt/${maven_package_name}/bin/mvn verify -P\!queue \
    && mv /opt/${gatk_dir_name}-${gatk_version}/protected/gatk-package-distribution/target/gatk-package-distribution-${gatk_version}.jar /opt/GenomeAnalysisTK.jar \
    && rm -rf /opt/${gatk_dir_name}-${gatk_version} /opt/${maven_package_name}

#
# blat
#

WORKDIR /usr/local/bin/
RUN wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/blat/blat && \
    chmod a+x blat


############
# ichorCNA #
############

RUN git clone https://github.com/broadinstitute/ichorCNA.git
RUN Rscript -e "install.packages(c('plyr', 'optparse','BiocManager')); BiocManager::install(c('HMMcopy','GenomeInfoDb'))"
RUN R CMD INSTALL ichorCNA


########
#VEP 90#
########

RUN cpan install DBI && cpan install Module::Build.pm

RUN mkdir /opt/vep/
WORKDIR /opt/vep

RUN git clone https://github.com/Ensembl/ensembl-vep.git
WORKDIR /opt/vep/ensembl-vep
RUN git checkout postreleasefix/90

RUN perl INSTALL.pl --NO_UPDATE

WORKDIR /
RUN ln -s /opt/vep/ensembl-vep/vep /usr/bin/variant_effect_predictor.pl


#install docker, instructions from https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-using-the-repository
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

RUN apt-get update

RUN apt-get install -y docker-ce

WORKDIR /opt/
RUN wget https://github.com/broadinstitute/cromwell/releases/download/36/cromwell-36.jar

#
# Cleanup
#

## Clean up
RUN cd / && \
   rm -rf /tmp/* && \
   apt-get autoremove -y && \
   apt-get autoclean -y && \
   rm -rf /var/lib/apt/lists/* && \
   apt-get clean && \
   rm -f /opt/*.bz2 /opt/*.gz

RUN mkdir /opt/files/

COPY add_annotations_to_table_helper.py /usr/local/bin/add_annotations_to_table_helper.py
COPY docm_and_coding_indel_selection.pl /usr/local/bin/docm_and_coding_indel_selection.pl
COPY runIchorCNA.R /usr/local/bin/runIchorCNA.R
COPY addReadCountsToVcfCRAM.py /usr/local/bin/addReadCountsToVcfCRAM.py
COPY configManta.hg38.py.ini /opt/files/configManta.hg38.py.ini
COPY ChromoSeq.hg38.bed /opt/files/ChromoSeq.hg38.bed
COPY GeneRegions.bed /opt/files/GeneRegions.bed
COPY ChromoSeq.translocations.fixed.v3.sorted.hg38.bedpe /opt/files/ChromoSeq.translocations.fixed.v3.sorted.hg38.bedpe
COPY ChromoSeqReporter.hg38.pl /usr/local/bin/ChromoSeqReporter.hg38.pl
COPY BlatContigs.pl /usr/local/bin/BlatContigs.pl
COPY pslScore.pl /usr/local/bin/pslScore.pl
COPY hg38.blacklist.merged.bed /opt/files/hg38.blacklist.merged.bed
COPY B38.callset.public.bedpe.gz /opt/files/B38.callset.public.bedpe.gz
COPY all.stranded.filtered.merged.bedpe.gz /opt/files/all.stranded.filtered.merged.bedpe.gz
COPY all.stranded.filtered.merged.bedpe.gz.tbi /opt/files/all.stranded.filtered.merged.bedpe.gz.tbi
COPY GeneCoverageRegions.bed /opt/files/GeneCoverageRegions.bed
COPY ChromoSeq.translocations.qc.bed /opt/files/ChromoSeq.translocations.qc.bed 
COPY nextera_hg38_500kb_median_normAutosome_median.rds_median.n9.rds /opt/files/nextera_hg38_500kb_median_normAutosome_median.rds_median.n9.rds
COPY basespace_cromwell.config /opt/files/basespace_cromwell.config
COPY Chromoseq_basespace.v9.wdl /opt/files/Chromoseq_basespace.v9.wdl
COPY all_sequences.dict /opt/files/all_sequences.dict
COPY all_sequences.fa.bed.gz /opt/files/all_sequences.fa.bed.gz
COPY all_sequences.fa.bed.gz.tbi /opt/files/all_sequences.fa.bed.gz.tbi
COPY all_sequences.fa.fai /opt/files/all_sequences.fa.fai
COPY driver.py /opt/files/driver.py

RUN chmod a+wrx /opt/files/*
RUN chmod a+wrx /usr/local/bin/*

