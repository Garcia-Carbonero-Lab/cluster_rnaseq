## Let snakemake use paired reads whenever possible
ruleorder: salmon_quant_paired > salmon_quant_se
ruleorder: star_align_paired > star_align_se

def get_hisat_reads(wildcards):
    if is_single_end(wildcards.sample):
        return f"{OUTDIR}/trimmed/{wildcards.sample}/{wildcards.sample}_R1.fastq.gz"
    else:
        return expand(f"{OUTDIR}/trimmed/{{sample}}/{{sample}}_R{{strand}}.fastq.gz", strand=[1,2], **wildcards)


### SALMON ###
rule salmon_quant_se:
    input:
        salmon_index=rules.salmon_index.output,
        se_reads=rules.trim_adapters_single_end.output.trimmed
    output:
        quant=f"{OUTDIR}/quant/salmon/{{sample}}/quant.sf"
    threads:
        get_resource('salmon_quant', 'threads')
    resources:
        mem=get_resource('salmon_quant', 'mem'),
        walltime=get_resource('salmon_quant', 'walltime')
    params:
        libtype=get_params('salmon', 'libtype'),
        quant_directory=directory(f"{OUTDIR}/quant/salmon/{{sample}}")
    log:
        f"{LOGDIR}/salmon_quant/{{sample}}.log"
    conda:
        '../envs/aligners.yaml'
    shell: 'salmon quant -i {input.salmon_index} -l {params.libtype} -r {input.se_reads} --validateMappings -o {params.quant_directory} --threads {threads}'


rule salmon_quant_paired:
    input:
        salmon_index=rules.salmon_index.output,
        r1_reads=f"{OUTDIR}/trimmed/{{sample}}/{{sample}}_R1.fastq.gz",
        r2_reads=f"{OUTDIR}/trimmed/{{sample}}/{{sample}}_R2.fastq.gz"
    output:
        quant= f"{OUTDIR}/quant/salmon/{{sample}}/quant.sf",
    threads:
        get_resource('salmon_quant', 'threads')
    resources:
        mem=get_resource('salmon_quant', 'mem'),
        walltime=get_resource('salmon_quant', 'walltime')
    params:
        libtype=get_params('salmon', 'libtype'),
        quant_directory=directory(f"{OUTDIR}/quant/salmon/{{sample}}")
    log:
        f"{LOGDIR}/salmon_quant/{{sample}}.log"
    conda:
        '../envs/aligners.yaml'
    shell: 'salmon quant -i {input.salmon_index} -l {params.libtype} -1 {input.r1_reads} -2 {input.r2_reads} --validateMappings -o {params.quant_directory} --threads {threads}'


### STAR ###
rule star_align_se:
    input:
        fq1=f"{OUTDIR}/trimmed/{{sample}}/{{sample}}_R1.fastq.gz",
        # path to STAR reference genome index
        index=rules.star_index.output
    output:
        aligned=OUTDIR + '/mapped/star/{sample}/Aligned.sortedByCoord.out.bam'
    threads:
        get_resource('star_align', 'threads')
    resources:
        mem=get_resource('star_align', 'mem'),
        walltime=get_resource('star_align', 'walltime')
    params:
        # optional parameters
        extra="--outSAMtype BAM SortedByCoordinate"
    log:
        f"{LOGDIR}/star/{{sample}}.log"
    conda:
        '../envs/aligners.yaml'
    script:
        "../scripts/star.py"


rule star_align_paired:
    input:
        fq1=f"{OUTDIR}/trimmed/{{sample}}/{{sample}}_R1.fastq.gz",
        fq2=f"{OUTDIR}/trimmed/{{sample}}/{{sample}}_R2.fastq.gz",
        # path to STAR reference genome index
        index=rules.star_index.output
    output:
        aligned=OUTDIR + '/mapped/star/{sample}/Aligned.sortedByCoord.out.bam'
    threads:
        get_resource("star_align", "threads")
    resources:
        mem=get_resource('star_align', 'mem'),
        walltime=get_resource('star_align', 'walltime')
    params:
        # optional parameters
        extra="--outSAMtype BAM SortedByCoordinate"
    log:
        f"{LOGDIR}/star/{{sample}}.log"
    conda:
        '../envs/aligners.yaml'
    script:
        "../scripts/star.py"


## HISAT-2 ##
rule hisat2_align:
    input:
        reads=get_hisat_reads,
        index_dir = rules.hisat2_index.output
    output:
        aligned=OUTDIR + "/mapped/hisat2/{sample}.bam"
    log:
        f"{LOGDIR}/hisat2_align/{{sample}}.log"
    params:
        extra="--new-summary",
        idx=config["ref"]["hisat2"]["hisat2_index"] + "/hisat2_index"
    threads:
        get_resource("hisat2_align", "threads")
    resources:
        mem=get_resource('hisat2_align', 'mem'),
        walltime=get_resource('hisat2_align', 'walltime')
    wrapper:
        "0.74.0/bio/hisat2/align"


rule hisat2_sort:
    input:
        aligned=OUTDIR + "/mapped/hisat2/{sample}.bam"
    output:
        sortedCoord=OUTDIR + "/mapped/hisat2/{sample}/Aligned.sortedByCoord.out.bam"
    log:
        f"{LOGDIR}/hisat2_sort/{{sample}}_sorted.log"
    threads:
        get_resource("hisat2_sort", "threads")
    resources:
        mem=get_resource('hisat2_sort', 'mem'),
        walltime=get_resource('hisat2_sort', 'walltime')
    conda:
        '../envs/aligners.yaml'
    shell:
        'samtools sort -@ {threads} -o {output.sortedCoord} {input.aligned}'
