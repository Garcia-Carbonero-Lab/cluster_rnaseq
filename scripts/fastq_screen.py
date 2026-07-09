import os
import re
import tempfile
from snakemake.shell import shell

_config = snakemake.params["fastq_screen_config"]
subset = snakemake.params.get("subset", 100000)
aligner = snakemake.params.get("aligner", "bowtie2")
extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True, append=True)

input_fastq = snakemake.input.fastq
prefix = re.split(r"\.fastq|\.fq|\.txt|\.seq", os.path.basename(input_fastq))[0]
with tempfile.TemporaryDirectory() as tempdir:
    if isinstance(_config, dict):
        config_file = f"{tempdir}/fastq_screen_config.txt"
        with open(config_file, "w") as fout:
            for label, indexes in _config["database"].items():
                for al, index in indexes.items():
                    fout.write("\t".join(["DATABASE", label, index, al.upper()]) + "\n")
            for al, path in _config["aligner_paths"].items():
                fout.write("\t".join([al.upper(), path]) + "\n")
    else:
        config_file = _config

    shell(
        "fastq_screen"
        " --threads {snakemake.threads}"
        " --aligner {aligner}"
        " --conf {config_file}"
        " --subset {subset}"
        " {extra}"
        " --force"
        " --outdir {tempdir}"
        " {input_fastq}"
        " {log}"
    )

    txt = snakemake.output.get("txt")
    if txt:
        shell("mv --verbose {tempdir}/{prefix}_screen.txt {txt} {log}")

    png = snakemake.output.get("png")
    if png:
        shell("mv --verbose {tempdir}/{prefix}_screen.png {png} {log}")