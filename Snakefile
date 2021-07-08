import glob
import os
import pandas as pd
import numpy as np
from snakemake.utils import validate, min_version

#### GLOBAL PARAMETERS ####

min_version('6.2.1')

configfile: "config.yaml"
validate(config, schema="schemas/config.schema.yaml")

OUTDIR = config['outdir']
LOGDIR = config['logdir']
IS_GENCODE = ('--gencode' if config['parameters']['salmon_index']['gencode'] else '')

#### GLOBAL scope functions ####
def get_resource(rule,resource) -> int:
	'''
	Attempt to parse config.yaml to retrieve resources available for a given
	rule. It will revert to default if a key error is found. Returns an int.
	with the allocated resources available for said rule. Ex: "threads": 1
	'''

	try:
		return config['resources'][rule][resource]
	except KeyError: # TODO: LOG THIS
		print(f'Failed to resolve resource for {rule}/{resource}: using default parameters')
		return config["resources"]['default'][resource]

#TODO: add defaults
def get_params(rule,param) -> int:
	'''
	Attempt to parse config.yaml to retrieve parameters available for a given
	rule. It will crash otherwise.
	''' 
	try:
		return config['parameters'][rule][param]
	except KeyError: # TODO: LOG THIS
		print(f'Failed to resolve parameter for {rule}/{param}: Exiting...')
		sys.exit(1)


def get_aligner(chosen_aligner:int) -> str:

	available_aligners = {0:'star', 1:'salmon', 2:'hisat2'}
	try:
		return available_aligners[chosen_aligner]
	except KeyError:
		print(f'Invalid aligner choice: {chosen_aligner}')
		sys.exit(1)
	
def get_reference_level(x):
    '''
	Gets the reference level for a column.
	'''
    levels = x.unique()
    is_reference = [lvl.startswith("*") for lvl in levels]
    if any(is_reference):    				
    	if sum(is_reference) > 1:
    		raise ValueError(f'More than two reference levels were specified ' +
							 f'for the same column: {levels[is_reference]}')
    	reference = levels[is_reference][0].strip("*")
    else:
    	reference = sorted(levels)[0]
    return reference

def get_variable_interest(design):
    '''
    Get the variable of interest for differential expression (variable after "~"). 
    '''
    split_covariates = [x.split("*") for x in design.split("+")]
    strip_covariates = [item.strip("~").strip(" ") for sublist in \
                        split_covariates for item in sublist]
    return strip_covariates[0]

#### LOAD SAMPLES TABLES ###

samples = pd.read_table(config["samples"]).set_index("sample", drop=False)
validate(samples, schema="schemas/samples.schema.yaml")

units = pd.read_table(config["units"], dtype=str).set_index(["sample", "lane"], drop=False)
units.index = units.index.set_levels([i.astype(str) for i in units.index.levels])  # enforce str in index
validate(units, schema="schemas/units.schema.yaml")

designmatrix = pd.read_table(config["parameters"]["deseq2"]["designmatrix"], \
							 dtype=str).set_index("sample", drop=False)
validate(designmatrix, schema="schemas/designmatrix.schema.yaml")

#### Get aligner ####
chosen_aligner = get_aligner(int(config['aligner']))

#### Subset the design matrix keeping only samples for DEA ####
DEAsamples = samples[samples["diffexp"]].index
designmatrix = designmatrix.loc[DEAsamples,]

#### Get reference level for each column in design matrix ####
designmatrix.drop(columns="sample", inplace=True)
ref_levels = designmatrix.apply(get_reference_level, axis="index")

#### Remove '*' prefix from design matrix cells ####
designmatrix = designmatrix.apply(lambda row: [str(x).removeprefix("*") \
                                              for x in row])

#### Get column of interest for differential expression
var_interest = get_variable_interest(config["parameters"]["deseq2"]["design"])

#### Contrasts ####
ref_interest = ref_levels[var_interest]
rest_levels = [y for y in designmatrix[var_interest].unique() \
              if y != ref_interest]
contrasts = [(z + "_vs_" + ref_interest, [z, ref_interest]) \
            for z in rest_levels]
contrasts = {key: value for (key, value) in contrasts}

#### Load rules ####
include: 'rules/common.smk'
include: 'rules/qc.smk'
include: 'rules/preprocess.smk'
include: 'rules/index.smk'
include: 'rules/align.smk'
include: 'rules/quantification.smk'
include: 'rules/deseq2.smk'

rule all:
	input:
		#f"{OUTDIR}/deseq2/salmon/counts.tsv"
		f"{OUTDIR}/qc/multiqc_report.html",
		f"{OUTDIR}/qc_concat/multiqc_report.html",
		expand(f"{OUTDIR}/deseq2/{chosen_aligner}/{{contrast}}/" + \
			  f"{{contrast}}_diffexp.xlsx", contrast=contrasts.keys()),
		expand(f"{OUTDIR}/deseq2/{chosen_aligner}/{{contrast}}/" + \
			  f"{{contrast}}_diffexp.tsv", contrast=contrasts.keys())
