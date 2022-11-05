rule link_local_data_directories:
    output: directory(config['local_data_dirs'])
    input: [f"{config['data_root']}/{dir}" for dir in config['data_dirs']]
    params:
        root=config['local_data_root'],
    shell:
        "for dir in {output}; do ln -s {params.root}/$dir; done"


rule link_fmt_studies_raw_data:
    output: 'raw/mgen'
    params:
        input='/pollard/data/metagenomes/fmt_studies'
    shell:
        "ln -s {params.input} {output}"
