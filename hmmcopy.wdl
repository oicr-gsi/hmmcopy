version 1.0

workflow hmmcopy {
input {
  File inputTumor
  File inputNormal
  String outputFileNamePrefix = ""
}

String sampleID = if outputFileNamePrefix=="" then basename(inputTumor, ".bam") else outputFileNamePrefix

call convertHMMcopy as normalConvert{ input: inputFile = inputNormal }
call convertHMMcopy as tumorConvert{ input: inputFile = inputTumor }

call runHMMcopy { input: tumorWig = tumorConvert.coverageWig, normalWig = normalConvert.coverageWig, outputPrefix = sampleID }

meta {
  author: "Peter Ruzanov"
  email: "peter.ruzanov@oicr.on.ca"
  description: "HMMcopy 2.0"
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
        name: "rstats-cairo/3.6",
        url: "http://cran.utstat.utoronto.ca/src/base/R-3/R-3.6.1.tar.gz"
      }
    ]
    output_meta: {
      resultiSegFile: ".seg file produced with HMMcopy",
      resultTsvFile: ".tsv file with all calls produced by HMMcopy",
      zippedPlots: "zipped plots in .png format"
    }
}

parameter_meta {
  inputTumor: "input .bam file for tumor sample"
  inputNormal: "input .bam file for normal sample"
  outputFileNamePrefix: "Output file(s) prefix"
}

output {
  File resultiSegFile = runHMMcopy.segFile
  File resultTsvFile  = runHMMcopy.tsvFile
  File zippedPlots    = runHMMcopy.zippedPlots
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
  String rScript  = "$RSTATS_CAIRO_ROOT/bin/Rscript"
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
  File zippedPlots = "~{outputPrefix}_images.zip"
}
}

