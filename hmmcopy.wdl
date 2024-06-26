version 1.0

struct hmmcopyResources {
  String resourceModule
  String cgFile
  String mapFile
}

workflow hmmcopy {
input {
  File inputTumor
  File inputNormal
  String reference
  String outputFileNamePrefix = ""
}

String sampleID = if outputFileNamePrefix=="" then basename(inputTumor, ".bam") else outputFileNamePrefix

Map [String,hmmcopyResources] resources = {
  "hg18": {"resourceModule": "hg19-hmmcopy/1.0",
           "cgFile": "/.mounts/labs/gsi/testdata/hmmcopy/hmmcopy_data/gc_hg18_chr22.wig",
           "mapFile":"/.mounts/labs/gsi/testdata/hmmcopy/hmmcopy_data/map_hg18_chr22.wig"
  },
  "hg19": {"resourceModule": "hg19-hmmcopy/1.0",
           "cgFile": "$HG19_HMMCOPY_ROOT/gc_hg19_10kb.wig",
           "mapFile":"$HG19_HMMCOPY_ROOT/map_hg19_10kb.wig"
  },
  "hg38": {"resourceModule": "hg38-hmmcopy/1.0",
           "cgFile": "$HG38_HMMCOPY_ROOT/gc_hg38_10kb.wig",
           "mapFile":"$HG38_HMMCOPY_ROOT/map_hg38_10kb.wig"
  }
}

call convertHMMcopy as normalConvert{ input: inputFile = inputNormal }
call convertHMMcopy as tumorConvert{ input: inputFile = inputTumor }

call runHMMcopy { input: tumorWig = tumorConvert.coverageWig,
                         normalWig = normalConvert.coverageWig,
                         cgFile = resources[reference].cgFile,
                         mapFile = resources[reference].mapFile,
                         modules = "hmmcopy/1.28.1 hmmcopy-scripts/1.1 ~{resources[reference].resourceModule} rstats/3.6",
                         outputPrefix = sampleID }

meta {
  author: "Peter Ruzanov"
  email: "peter.ruzanov@oicr.on.ca"
  description: "This Seqware workflow is a wrapper for HMMcopy which is a CNV analysis tool capable of making calls using paired Normal/Tumor data. The tool detects copy-number changes and allelic imbalances (including LOH) using deep-sequencing data.Corrects GC and mappability biases for readcounts (i.e. coverage) in non-overlapping windows of fixed length for single whole genome samples, yielding a rough estimate of copy number for furthur analysis. Designed for rapid correction of high coverage whole genome tumour and normal samples.\n\n![hmmcopy, how it works](docs/hmmcopy_wf.png)"
  dependencies: [
      {
        name: "hmmcopy-utils/0.1.1",
        url: "https://bioconductor.org/packages/HMMcopy/"
      },
      {
        name: "hmmcopy/1.28.1",
        url: "https://bioconductor.org/packages/HMMcopy/"
      },
      {
        name: "rstats/3.6",
        url: "http://cran.utstat.utoronto.ca/src/base/R-3/R-3.6.1.tar.gz"
      }
    ]
    output_meta: {
    resultiSegFile: {
        description: ".seg file produced with HMMcopy",
        vidarr_label: "resultiSegFile"
    },
    resultTsvFile: {
        description: ".tsv file with all calls produced by HMMcopy",
        vidarr_label: "resultTsvFile"
    },
    cgBiasImage: {
        description: "Plot showing the results of CG bias test",
        vidarr_label: "cgBiasImage"
    },
    segImage: {
        description: "Plot shows the segmentation data",
        vidarr_label: "segImage"
    }
}
}

parameter_meta {
  inputTumor: "input .bam file for tumor sample"
  inputNormal: "input .bam file for normal sample"
  reference: "reference assembly id"
  outputFileNamePrefix: "Output file(s) prefix"
}

output {
  File resultiSegFile = runHMMcopy.segFile
  File resultTsvFile  = runHMMcopy.tsvFile
  File cgBiasImage    = runHMMcopy.cgBiasImage
  File segImage       = runHMMcopy.segImage

}

}

# ==========================================
#  Convert inputs with HMMcopy utils
# ==========================================
task convertHMMcopy {
input {
  File inputFile
  String modules  = "hmmcopy-utils/0.1.1"
  String readCounter = "$HMMCOPY_UTILS_ROOT/bin/readCounter"
  String? chromosomes
  Int? window
  Int jobMemory   = 8
  Int timeout     = 20
}

parameter_meta {
  inputFile: "input .bam file for conversion"
  modules: "required modules, basicall hmmcopy utils"
  readCounter: "Path to readCounter utility"
  chromosomes: "comma-separated list of chromosomes to use, default is ALL"
  window: "Resolution of a bin, in bases, default is 1000"
  jobMemory: "memory for this job, in Gb"
  timeout: "Timeout in hours, needed to override imposed limits"
}

command <<<
  set -euxo pipefail
  ~{readCounter} -b ~{inputFile}
  ~{readCounter} ~{"-w " + window} ~{"-c " + chromosomes} ~{inputFile} > ~{basename(inputFile, '.bam')}_reads.wig
>>>

runtime {
  memory:  "~{jobMemory} GB"
  modules: "~{modules}"
  timeout: "~{timeout}"
}

output {
  File coverageWig = "~{basename(inputFile, '.bam')}_reads.wig"
}
}

#=============================================================
# Task for running HMMcopy
#=============================================================
task runHMMcopy {
input {
  File tumorWig
  File normalWig
  String modules
  String rScript  = "$RSTATS_ROOT/bin/Rscript"
  String hmmcopyScript = "$HMMCOPY_SCRIPTS_ROOT/run_HMMcopy.r"
  String outputPrefix
  String cgFile
  String mapFile
  Int jobMemory = 8
  Int timeout   = 20
}

parameter_meta {
  tumorWig: "Input tumor data converted with readCounter"
  normalWig: "Input normal data converted with readCounter"
  modules: "list of data/software modules needed for the task"
  rScript: "Path to Rscript"
  hmmcopyScript: "Path to .R script that runs HMMcopy pipeline"
  outputPrefix: "Output prefix for the result files"
  cgFile: "Path to CG content file"
  mapFile: "Path to mappability file"
  jobMemory: "memory in GB for this job"
  timeout: "Timeout in hours, needed to override imposed limits"
}

command <<<
  set -euxo pipefail
  ~{rScript} ~{hmmcopyScript} ~{normalWig} ~{tumorWig} ~{cgFile} ~{mapFile} ~{outputPrefix}
  zip -q ~{outputPrefix}_images.zip *.png
>>>

runtime {
  modules: "~{modules}"
  memory: "~{jobMemory} GB"
  timeout: "~{timeout}"
}

output {
  File segFile = "~{outputPrefix}.seg"
  File tsvFile = "~{outputPrefix}.tsv"
  File cgBiasImage = "~{outputPrefix}.bias_plot.png"
  File segImage = "~{outputPrefix}.s_plot.png"
}
}

