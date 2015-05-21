#!/usr/bin/env nextflow

/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */
params.pair1 = "../data/*_1.fastq"
params.pair2 = "../data/*_2.fastq"
params.genome = "../data/Danio_rerio.Zv9.66.dna.fa"

/*
 * emits all reads ending with "_1" suffix and map them to pair containing the common
 * part of the name
 */
reads1 = Channel
    .fromPath( params.pair1 )
    .map { path -> [ path.baseName[0..-3], path ] }

/*
 * as above for "_2" read pairs
 */
reads2 = Channel
    .fromPath( params.pair2 )
    .map { path -> [ path.baseName[0..-3], path ] }

/*
 * Match the pairs emitted by "read1" and "read2" channels having the same 'key'
 * and emit a new pair containing the expected read-pair files
 */
read_pairs = reads1
        .phase(reads2)
        .map { pair1, pair2 -> [ pair1[0], pair1[1], pair2[1] ] }

/*
 * the reference genome file
 */
genome_file = file(params.genome)

/*
 * Step 1. Build the genome index
 */
process buildIndex {
    input:
    file genome_file

    output:
    file 'genome.index*' into genome_index

    """
    bowtie2-build ${genome_file} genome.index
    """
}

/*
 * Step 2. Map each read-pair using Tophat2
 */
process mapping {
    tag { pair_id }

    input:
    file genome_file
    file genome_index from genome_index.first()
    set pair_id, file(read1), file(read2) from read_pairs

    output:
    set pair_id, "tophat_out/accepted_hits.bam" into bam

    """
    tophat2 genome.index ${read1} ${read2}
    """
}

/*
 * Step 3. Assemble the transcript
 */
process makeTranscript {
    tag { pair_id }

    input:
    set pair_id, bam_file from bam

    output:
    set pair_id, 'transcripts.gtf' into transcripts

    """
    cufflinks ${bam_file} 2&>1
    """
}

/*
 * Fork data stream
 */
transcripts_for_output = Channel.create()
transcripts_for_drawing = Channel.create()
transcripts_for_counting = Channel.create()
transcripts.into(transcripts_for_output, transcripts_for_drawing,
                 transcripts_for_counting)

/*
 * Step 4. Draw the transcripts
 */
process drawTranscripts {
    tag { pair_id }

    input:
    set val(pair_id), file(filename) from transcripts_for_drawing

    output:
    set val(pair_id), file('transcripts.png') into transcript_images

    """
    gt sketch -input gtf -addintrons -force transcripts.png ${filename}
    """
}

/*
 * Step 5. Count the transcripts
 */
process countTranscripts {
    tag { pair_id }

    input:
    set val(pair_id), file(filename) from transcripts_for_counting

    output:
    set val(pair_id), stdout into stats

    """
    gt gtf_to_gff3 -tidy ${filename} | gt gff3 -sort -retainids | gt stat
    """
}

/*
 * Step 6. Output results
 */
transcripts_for_output
  .collectFile() {
    [ "${it[0]}_transcript.gtf", it[1] ]
  }
  .subscribe {
    println it
  }

transcript_images
  .collectFile() {
    [ "${it[0]}_transcript.png", it[1] ]
  }
  .subscribe {
    println it
  }

stats
  .flatMap()
  .subscribe {
    println it
  }