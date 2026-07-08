"""Snakemake script for fastqc."""

from os import path
import re
from tempfile import TemporaryDirectory
from snakemake.shell import shell

extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Memoria por hilo (ver https://github.com/s-andrews/FastQC/blob/master/fastqc#L201-L222)
mem_overhead_factor = snakemake.params.get("mem_overhead_factor", 0.1)
assert (
    0 <= mem_overhead_factor < 1
), f"mem_overhead_factor must be between 0 and 1, got {mem_overhead_factor}"

mem_mb = snakemake.resources.mem_mb
mem_per_thread_mb = int(mem_mb / snakemake.threads * (1.0 - mem_overhead_factor))


def basename_without_ext(file_path):
    """Devuelve el basename sin extension(es)."""
    base = path.basename(file_path)
    base = re.sub("\\.gz$", "", base)
    base = re.sub("\\.bz2$", "", base)
    base = re.sub("\\.txt$", "", base)
    base = re.sub("\\.fastq$", "", base)
    base = re.sub("\\.fq$", "", base)
    base = re.sub("\\.sam$", "", base)
    base = re.sub("\\.bam$", "", base)
    return base


if len(snakemake.input) > 1:
    raise IOError("Got multiple input files, I don't know how to process them!")

with TemporaryDirectory() as tempdir:
    shell(
        "fastqc"
        " --threads {snakemake.threads}"
        " --memory {mem_per_thread_mb}"
        " {extra}"
        " --outdir {tempdir:q}"
        " {snakemake.input[0]:q}"
        " {log}"
    )

    output_base = basename_without_ext(snakemake.input[0])
    html_path = path.join(tempdir, output_base + "_fastqc.html")
    zip_path = path.join(tempdir, output_base + "_fastqc.zip")

    if snakemake.output.html != html_path:
        shell("mv {html_path:q} {snakemake.output.html:q}")

    if snakemake.output.zip != zip_path:
        shell("mv {zip_path:q} {snakemake.output.zip:q}")