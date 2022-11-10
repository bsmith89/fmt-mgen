rule link_fmt_studies_raw_data:
    output:
        "raw/mgen",
    params:
        input="/pollard/data/metagenomes/fmt_studies",
    shell:
        "ln -s {params.input} {output}"


rule link_local_data_directories:
    output:
        directory(config["local_data_dirs"]),
    input:
        [f"{config['local_data_root']}/{dir}" for dir in config["local_data_dirs"]],
    params:
        root=config["local_data_root"],
    shell:
        """
        for dir in {output}
        do
            ln -s "{params.root}/$dir"
        done
        """


rule link_secure_local_data_directories:
    output:
        directory(config["secure_local_data_dirs"]),
    input:
        [
            f"{config['secure_local_data_root']}/{dir}"
            for dir in config["secure_local_data_dirs"]
        ],
    params:
        root=config["secure_local_data_root"],
    shell:
        """
        for dir in {output}
        do
            ln -s "{params.root}/$dir"
        done
        """


rule link_local_GRCh38_index:
    output:
        "raw/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.1.bt2",
        "raw/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.2.bt2",
        "raw/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.3.bt2",
        "raw/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.4.bt2",
        "raw/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.rev.1.bt2",
        "raw/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.rev.2.bt2",
    input:
        [
            f"/pollard/data/vertebrate_genomes/human/hg38/hg38/human_hg38.{stem}.bt2"
            for stem in ["1", "2", "3", "4", "rev.1", "rev.2"]
        ],
    shell:
        """
        ln -s {input[0]} {output[0]}
        ln -s {input[1]} {output[1]}
        ln -s {input[2]} {output[2]}
        ln -s {input[3]} {output[3]}
        ln -s {input[4]} {output[4]}
        ln -s {input[5]} {output[5]}
        """


ruleorder: link_local_GRCh38_index > unpack_GRCh38_index
