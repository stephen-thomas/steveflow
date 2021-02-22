#!/usr/bin/env nextflow
/*
========================================================================================
               
========================================================================================
 #### Homepage / Documentation
 https://github.com/scilifelab/NGI-ExoSeq
 #### Authors
 Senthilkumar Panneerselvam @senthil10 <senthilkumar.panneerselvam@scilifelab.se>
 Phil Ewels @ewels <phil.ewels@scilifelab.se>
 Alex Peltzer @alex_peltzer <alexander.peltzer@qbic.uni-tuebingen.de>
 Marie Gauder <marie.gauder@student.uni-tuebingen.de>
 Some code parts were lent from other NGI-Pipelines (e.g. CAW), specifically the error
 handling, logging messages. Thanks for that @CAW guys.
----------------------------------------------------------------------------------------
Developed based on GATK's best practise, takes set of FASTQ files and performs:
 - alignment (BWA)
 - recalibration (GATK)
 - realignment (GATK)
 - variant calling (GATK)
 - variant evaluation (SnpEff)
*/

params.index = 'receive-data-nextflow/result.csv'

Channel
    .fromPath(params.index)
    .splitCsv(header: ['name', 'r1', 'r2', 'fasta', 'root'])
    .multiMap { row ->
      reads: tuple(row.name, file(row.r1), file(row.r2))
      genomes: tuple(row.name, file(row.fasta))
      metadata: tuple(row.name, row.root)
    }
    .set { samples_ch }

process IndexReference {
  echo true
  container 'mblanche/bwa-samtools'
  input:
    tuple name, file(genome) from samples_ch.genomes

  output:
    tuple name, file(genome), file('*') into bwa_index_ch

  script:
  """
  bwa index $genome
  """
}

process bwaMem {
    cpus 4
    memory '16 GB'

    container 'mblanche/bwa-samtools'

    input:
    tuple name, file(R1s), file(R2s), file(genome), file(index) from samples_ch.reads.join(bwa_index_ch)

    output:
    file '*.bam' into bams_ch

    script:
    """
    bwa mem -5SP -T0 -t ${task.cpus} ${genome} ${R1s} ${R2s} > ${name}.bam
    """
}

bams_ch.view()
