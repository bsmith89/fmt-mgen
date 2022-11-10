# Ecological Dynamics from Metagenomic Data in FMT Experiments

## Getting Started

- Clone this project: `$ git clone git@github.com:bsmith89/fmt-mgen.git fmt-mgen`
- `$ cd fmt-mgen`
- Install snakemake, activate conda environment with snakemake, etc.
- Edit `env_local` to activate this environment
- `$ source env`
- `$ smake initialize_project_config`
- Create and link scratch directories, e.g.
    - `$ ln -s /pollard/scratch/$USER/fmt-mgen/raw raw`
    - `$ ln -s /pollard/scratch/$USER/fmt-mgen/ref ref`
    - `$ ln -s /pollard/scratch/$USER/fmt-mgen/data data`
    - `$ ln -s /pollard/scratch/$USER/fmt-mgen/sdata sdata`
- Link raw data and reference databases, e.g.
    - `$ ln -s /pollard/data/vertebrate_genomes/human/hg38/hg38/human_hg38.1.bt2 ref/GRCh38.1.bt2`
    - `$ ln -s /pollard/data/gt-pro-db /ref/gtpro`
    - `$ ln -s /pollard/data/metagenomes/fmt_studies/ raw/mgen`
- (See <https://github.com/bsmith89/fmt-mgen/blob/pollard-local/snake/local.smk> for how I automate the above.)
- If everything above has gone well, then run `$ smake -j20 data/sp-102506.test.a.r.proc.gtpro.tsv.bz2`
- Profit!
