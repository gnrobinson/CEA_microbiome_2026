#!/bin/bash
#SBATCH -J Guy_QIIME # give job a name
#SBATCH -D /home/melland/taylor/nico_microbiome ##change
#SBATCH -t 200:00:00   # amount of time you give the job
#SBATCH -N 1    # num of nodes, leave at 1
#SBATCH -n 16   # num of threads, keep the same as in script
#SBATCH -p ecl243   # partition you run it on (low med or high)
#SBATCH -A ecl243grp
#SBATCH --mem=180GB
#SBATCH --mail-type=END   #get an email when job ends
#SBATCH --mail-user=gnrobinson@ucdavis.edu
#SBATCH -o PHYLO_QIIME-%j.output
#SBATCH -e PHYLO_QIIME-%j.err

module load conda/qiime2/2023.2

qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path manifest_ITS.tsv \
  --output-path Data/paired-end-demux.qza \
  --input-format PairedEndFastqManifestPhred33V2

#demultiplex
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs Data/paired-end-demux.qza \
  --p-trunc-len-f 260 \
  --p-trunc-len-r 250 \
  --o-table Data/paired-end-demux_table_dada.qza \
  --o-representative-sequences Data/DeRep-seqs_dada.qza \
  --o-denoising-stats DeRep_dada_stats.qza \
  --p-n-threads 8

qiime vsearch cluster-features-de-novo \
  --i-table Data/paired-end-demux_table_dada.qza \
  --i-sequences Data/DeRep-seqs_dada.qza \
  --p-perc-identity 0.99 \
  --p-threads 16 \
  --o-clustered-table Data/paired_end_demux_table-dn-99_dada.qza \
  --o-clustered-sequences Data/DeRep-seqs-dn-99_dada.qza

qiime feature-table summarize \
  --i-table Data/paired_end_demux_table-dn-99_dada.qza \
  --o-visualization Data/paired_end_demux_table-dn-99_feature_table_dada.qzv \
  --m-sample-metadata-file Data/metadata.txt

#Phylogenetics
#Alignment
qiime alignment mafft \
  --i-sequences Data/DeRep-seqs-dn-99_dada.qza \
  --o-alignment Data/aligned-rep-seqs_dada.qza

#Masking sites
qiime alignment mask \
  --i-alignment Data/aligned-rep-seqs_dada.qza \
  --o-masked-alignment Data/masked-aligned-rep-seqs_dada.qza

#Creating a tree
qiime phylogeny fasttree \
  --i-alignment Data/masked-aligned-rep-seqs_dada.qza \
  --o-tree Data/unrooted-tree_dada.qza

#Midpoint root
qiime phylogeny midpoint-root \
  --i-tree Data/unrooted-tree_dada.qza \
  --o-rooted-tree Data/rooted-tree_dada.qza

## classifying ASVs into taxa
 qiime feature-classifier classify-sklearn \
 --i-classifier unite_classifier.qza \
 --i-reads Data/DeRep-seqs-dn-99_dada.qza \
 --o-classification Data/sklearn_taxonomy_dada.qza \
 --p-reads-per-batch 1000 \
 --p-n-jobs 16

## filtering feature table - mt, cp, cyano, archaea
 qiime taxa filter-table \
 --i-table Data/paired_end_demux_table-dn-99_dada.qza \
 --i-taxonomy Data/sklearn_taxonomy_dada.qza \
 --p-exclude mitochondria,chloroplast,cyanobacteria,archaea \
 --o-filtered-table Data/feature-table-filtered_ITS_unitev8.qza

## filtering sequences - mt, cp, cyano, archaea
qiime taxa filter-seqs \
  --i-sequences Data/DeRep-seqs-dn-99_dada.qza \
  --i-taxonomy Data/sklearn_taxonomy_dada.qza \
  --p-exclude mitochondria,chloroplast,cyanobacteria,archaea \
  --o-filtered-sequences Data/sequences-filtered-97_dada.qza

