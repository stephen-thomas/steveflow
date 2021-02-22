#!/usr/bin/env nextflow
/*
========================================================================================
               SteveFlow / Multiple Sample BWA Alignment Pipeline
========================================================================================
 #### Homepage / Documentation
 https://github.com/stephen-thomas/steveflow
 #### Authors
 Stephen Thomas <stephenthomasonline@gmail.com>
----------------------------------------------------------------------------------------
Takes set of FASTQ files and performs:
 - alignment (BWA)
*/

// Help message
helpMessage = """
===============================================================================
stephen-thomas/steveflow : Distributed BWA alignemnts for many samples
===============================================================================
Usage: nextflow stephen-thomas/steveflow --index index.csv
This is a typical usage where the required parameters (with no defaults) were
given. The available paramaters are listed below based on category
Required parameters:
    --index                       csv file containing inputs
""".stripIndent()

// Variables and defaults
params.index = 'receive-data-nextflow/result.csv'
params.help = false

// Show help when needed
if (params.help){
    log.info helpMessage
    exit 0
}

// Add Metadata to log message
if (!params.index){
    exit 1, "No Exome Capturing Kit specified!"

// Create a summary for the logfile
def summary = [:]
summary['Run Name']       = workflow.runName
summary['Index']          = params.index
summary['Working dir']    = workflow.workDir
summary['Container']      = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="

// Channel for Input Files
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
  tag "$name"

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
    tag "$name"

    cpus 4
    memory '16 GB'

    container 'mblanche/bwa-samtools'

    input:
    tuple name, file(R1s), file(R2s), file(genome), file(index) from samples_ch.reads.join(bwa_index_ch)

    output:
    file '${name}_bwa.bam' into sorted_bam_ch

    script:
    def avail_mem = task.memory ? "-m ${task.memory.toMega().intdiv(task.cpus)}M" : ''

    """
    bwa mem \\
    -5SP -T0 -t ${task.cpus} \\
    ${genome} ${R1s} ${R2s} \\
    | samtools ${avail_mem} sort -O bam - > ${name}_bwa.bam
    > ${name}.bam
    """
}

bams_ch.view()
