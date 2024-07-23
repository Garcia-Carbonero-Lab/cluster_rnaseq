### Umis group and Deduplication ###

rule umi_group:
    input:
        aligned=OUTDIR + '/mapped/star/{sample}/Aligned.sortedByCoord.out.bam',
        indexed=OUTDIR + '/mapped/star/{sample}/Aligned.sortedByCoord.out.bam.bai'
    output:
        grouped=OUTDIR + '/mapped/star/umi_grouped/{sample}/Aligned.sortedByCoord.umi_grouped.out.bam'
    threads:
        get_resource('umi_group', 'threads')
    resources:
        mem_mb=get_resource('umi_group', 'mem_mb'),
            runtime=get_resource('umi_group', 'runtime')        
    log:
        f"{LOGDIR}/umi_group/{{sample}}.log",
    conda:
        "../envs/umis.yaml"        
    shell:
	    "umi_tools group --method unique --output-bam -I {input.aligned} -S {output.grouped} --log={log}"


rule dedup:
    input:
        grouped=OUTDIR + '/mapped/star/umi_grouped/{sample}/Aligned.sortedByCoord.umi_grouped.out.bam',
        indexed=OUTDIR + '/mapped/star/umi_grouped/{sample}/Aligned.sortedByCoord.umi_grouped.out.bam.bai'
    output:
        deduped=OUTDIR + '/mapped/star/dedup/{sample}/Aligned.sortedByCoord.dedup.out.bam'
    
    threads:
        get_resource('dedup', 'threads')
    resources:
            mem_mb=get_resource('dedup', 'mem_mb'),
            runtime=get_resource('dedup', 'runtime')        
    log:
        f"{LOGDIR}/dedup/{{sample}}.log",
    conda:
        "../envs/umis.yaml"
    shell:
	    "umi_tools dedup --method unique -I {input.grouped} -S {output.deduped} --log={log}"