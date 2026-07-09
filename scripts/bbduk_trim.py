import os
from snakemake.shell import shell

# --- Reemplazo de get_java_opts sin depender de snakemake_wrapper_utils ---
mem_mb = snakemake.resources.get("mem_mb")
java_opts = snakemake.params.get("java_opts", "")
if mem_mb:
    java_opts = f"{java_opts} -Xmx{int(mem_mb)}m".strip()

extra = snakemake.params.get("extra", "")
adapters = snakemake.params.get("adapters", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

n = len(snakemake.input.sample)
assert n == 1 or n == 2, "input->sample must have 1 (single-end) or 2 (paired-end) elements."

if n == 1:
    reads = "in={}".format(snakemake.input.sample[0])
    trimmed = "out={}".format(snakemake.output.trimmed)
else:
    reads = "in={} in2={}".format(*snakemake.input.sample)
    trimmed = "out={} out2={}".format(*snakemake.output.trimmed)

singleton = snakemake.output.get("singleton", "")
if singleton:
    singleton = f"outs={singleton}"

discarded = snakemake.output.get("discarded", "")
if discarded:
    discarded = f"outm={discarded}"

stats = snakemake.output.get("stats", "")
if stats:
    stats = f"stats={stats}"

shell(
    "bbduk.sh {java_opts} t={snakemake.threads} "
    "{reads} "
    "{adapters} "
    "{extra} "
    "{trimmed} {singleton} {discarded} "
    "{stats} "
    "{log}"
)