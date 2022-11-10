rule start_shell_gtpro:
    container:
        config["container"]["gtpro"]
    shell:
        "bash"


rule download_gtpro_reference_core_snps:
    output:
        "raw/gtpro_refs/variation_in_species/{species_id}/core_snps.vcf.gz",
    params:
        url=lambda w: f"https://fileshare.czbiohub.org/s/waXQzQ9PRZPwTdk/download?path=%2Fvariation_in_species%2F{w.species_id}&files=core_snps.vcf.gz",
    container:
        None
    shell:
        curl_recipe


rule run_gtpro:
    output:
        temp("{stem}.gtpro_raw.gz"),
    input:
        r="{stem}.fq.gz",
        kmer_index="ref/gtpro/20190723_881species_optimized_db_kmer_index.bin",
        lmer_index="ref/gtpro/20190723_881species_optimized_db_lmer_index_32.bin",
        mmer_bloom="ref/gtpro/20190723_881species_optimized_db_mmer_bloom_36.bin",
        snp="ref/gtpro/20190723_881species_optimized_db_snps.bin",
    params:
        db_l=32,
        db_m=36,
        db_name="ref/gtpro/20190723_881species",
    threads: 4
    resources:
        mem_mb=60000,
        pmem=60000 // 4,
        walltime_hr=4,
    container:
        config["container"]["gtpro_old"]
    shell:
        dd(
            """
        GT_Pro genotype -t {threads} -l {params.db_l} -m {params.db_m} -d {params.db_name} -f -o {output} {input.r}
        mv {output}.tsv.gz {output}
        """
        )


rule load_gtpro_snp_dict:
    output:
        "ref/gtpro.snp_dict.db",
    input:
        "ref/gtpro/variants_main.covered.hq.snp_dict.tsv",
    shell:
        dd(
            """
        rm -f {output}.tmp
        sqlite3 {output}.tmp <<EOF
        CREATE TABLE snp (
          species TEXT
          , global_pos INT
          , contig TEXT
          , local_pos INT
          , ref_allele VARCHAR(1)
          , alt_allele VARCHAR(1)
          , PRIMARY KEY (species, global_pos)
        );
        EOF
        cat {input} \
            | tqdm --unit-scale 1 \
            | sqlite3 -separator '\t' {output}.tmp '.import /dev/stdin snp'
        mv {output}.tmp {output}
        """
        )


# NOTE: Comment-out this rule after files have been completed to
# save DAG processing time.
rule gtpro_finish_processing_reads:
    output:
        "{stem}.gtpro_parse.tsv.bz2",
    input:
        raw="{stem}.gtpro_raw.gz",
        db="ref/gtpro.snp_dict.db",
    shell:
        dd(
            """
        rm -f {output}.tmp
        sqlite3 {output}.tmp <<EOF

        CREATE TABLE _gtpro_tally (
            snv_id TEXT
          , tally INT
        );

        EOF
        zcat {input.raw} \
            | tqdm --unit-scale 1 \
            | sqlite3 -separator '\t' {output}.tmp '.import /dev/stdin _gtpro_tally'
        (
        sqlite3 -header -separator '\t' {output}.tmp <<EOF

        ATTACH DATABASE '{input.db}' AS ref;

        CREATE TEMPORARY VIEW gtpro_tally AS
        SELECT
          snv_id
        , substr(snv_id, 1, 6) AS species
        , substr(snv_id, 7, 1) AS snv_type
        , substr(snv_id, 8) AS global_pos
        , tally
        FROM _gtpro_tally
        ;

        CREATE TEMPORARY VIEW snp_hit AS
        SELECT *
        , CASE snv_type
            WHEN '0' THEN tally
            WHEN '1' THEN 0
        END AS ref_count
        , CASE snv_type
            WHEN '0' THEN 0
            WHEN '1' THEN tally
        END AS alt_count
        FROM gtpro_tally
        JOIN ref.snp USING (species, global_pos)
        ;

        SELECT
            species
            , global_pos
            , contig
            , local_pos
            , ref_allele
            , alt_allele
            , SUM(ref_count) AS ref_count
            , SUM(alt_count) AS alt_count
        FROM snp_hit
        GROUP BY species, global_pos
        ORDER BY CAST(species AS INT), CAST(global_pos AS INT)
        ;

        EOF
        ) | bzip2 -c > {output}.tmp2
        rm {output}.tmp
        mv {output}.tmp2 {output}
        """
        )


# Helper rule that pre-formats paths from library_id to r1 and r2 paths.
rule count_species_lines_from_both_reads_helper:
    output:
        temp("data/group/{group}/a.r.{stem}.gtpro_species_tally.tsv.args"),
    params:
        mgen=lambda w: config["mgen_group"][w.group],
    run:
        with open(output[0], "w") as f:
            for mgen in params.mgen:
                print(
                    mgen,
                    f"data/reads/{mgen}/r1.{wildcards.stem}.gtpro_parse.tsv.bz2",
                    f"data/reads/{mgen}/r2.{wildcards.stem}.gtpro_parse.tsv.bz2",
                    sep="\t",
                    file=f,
                )


rule count_species_lines_from_both_reads:
    output:
        "data/group/{group}/a.r.{stem}.gtpro_species_tally.tsv",
    input:
        script="scripts/tally_gtpro_species_lines.sh",
        r1=lambda w: [
            f"data/reads/{mgen}/r1.{{stem}}.gtpro_parse.tsv.bz2"
            for mgen in config["mgen_group"][w.group]
        ],
        r2=lambda w: [
            f"data/reads/{mgen}/r2.{{stem}}.gtpro_parse.tsv.bz2"
            for mgen in config["mgen_group"][w.group]
        ],
        helper="data/group/{group}/a.r.{stem}.gtpro_species_tally.tsv.args",
    threads: 24
    shell:
        r"""
        parallel --colsep='\t' --bar -j {threads} \
                bash {input.script} :::: {input.helper} \
            > {output}.tmp
        mv {output}.tmp {output}

        """


# NOTE: Comment out this rule to speed up DAG evaluation.
rule estimate_all_species_horizontal_coverage:
    output:
        "data/{stem}.gtpro.horizontal_coverage.tsv",
    input:
        script="scripts/estimate_all_species_horizontal_coverage_from_position_tally.py",
        snps="ref/gtpro/variants_main.covered.hq.snp_dict.tsv",
        r="data/{stem}.gtpro_species_tally.tsv",
    shell:
        "{input.script} {input.snps} {input.r} {output}"


checkpoint select_species_with_greater_max_coverage_gtpro:
    output:
        "data/group/{group}/a.{stem}.gtpro.horizontal_coverage.filt-h{cvrg_thresh}-n{num_samples}.list",
    input:
        "data/group/{group}/a.{stem}.gtpro.horizontal_coverage.tsv",
    params:
        cvrg_thresh=lambda w: float(w.cvrg_thresh) / 100,
        num_samples=lambda w: int(w.num_samples),
    run:
        horizontal_coverage = (
            pd.read_table(
                input[0],
                names=["sample_id", "species_id", "horizontal_coverage"],
                index_col=["sample_id", "species_id"],
            )
            .squeeze()
            .unstack(fill_value=0)
        )
        with open(output[0], "w") as f:
            # Select species with >=2 libraries with more coverage than the threshold
            for species_id in idxwhere(
                (horizontal_coverage >= params.cvrg_thresh).sum() >= params.num_samples
            ):
                print(species_id, file=f)


def checkpoint_select_species_with_greater_max_coverage_gtpro(
    group, stem, cvrg_thresh, num_samples, require_in_species_group=False
):
    potential_species = set(config["species_group"][group])
    cvrg_thresh = int(cvrg_thresh * 100)
    with open(
        checkpoints.select_species_with_greater_max_coverage_gtpro.get(
            group=group,
            stem=stem,
            cvrg_thresh=cvrg_thresh,
            num_samples=num_samples,
        ).output[0]
    ) as f:
        if require_in_species_group:
            out = list(
                set([l.strip() for l in f]) & set(config["species_group"][group])
            )
        else:
            out = [l.strip() for l in f]
    return out


# Helper rule that pre-formats paths from library_id *.gtpro_parse.tsv.bz2 files.
rule concatenate_mgen_group_one_read_count_data_from_one_species_helper:
    output:
        temp("data/group/{group}/a.{r12}.{stem}.gtpro.tsv.bz2.args"),
    input:
        gtpro=lambda w: [
            f"data/reads/{mgen}/{{r12}}.{{stem}}.gtpro_parse.tsv.bz2"
            for mgen in config["mgen_group"][w.group]
        ],
    run:
        with open(output[0], "w") as f:
            for mgen in config["mgen_group"][wildcards.group]:
                print(
                    mgen,
                    f"data/reads/{mgen}/{wildcards.r12}.{wildcards.stem}.gtpro_parse.tsv.bz2",
                    sep="\t",
                    file=f,
                )


# NOTE: Comment out this rule to speed up DAG evaluation.
# Selects a single species from every file and concatenates.
rule concatenate_mgen_group_one_read_count_data_from_one_species:
    output:
        "data/group/{group}/sp-{species}.{r12}.{stem}.gtpro.tsv.bz2",
    input:
        script="scripts/select_gtpro_species_lines.sh",
        gtpro=lambda w: [
            f"data/reads/{mgen}/{{r12}}.{{stem}}.gtpro_parse.tsv.bz2"
            for mgen in config["mgen_group"][w.group]
        ],
        helper="data/group/{group}/a.{r12}.{stem}.gtpro.tsv.bz2.args",
    wildcard_constraints:
        r12="r[12]",
    params:
        species=lambda w: w.species,
    threads: 6
    shell:
        dd(
            """
        parallel --colsep='\t' --bar -j {threads} \
                {input.script} {params.species} :::: {input.helper} \
            | bzip2 -c \
            > {output}.tmp
        mv {output}.tmp {output}
        """
        )


# NOTE: Hub-rule: Comment out this rule to reduce DAG-building time
# once it has been run for the focal group/species.
rule merge_both_reads_species_count_data:
    output:
        "{stemA}/sp-{species}.r.{stemB}.gtpro.tsv.bz2",
    input:
        script="scripts/sum_merged_gtpro_tables.py",
        r1="{stemA}/sp-{species}.r1.{stemB}.gtpro.tsv.bz2",
        r2="{stemA}/sp-{species}.r2.{stemB}.gtpro.tsv.bz2",
    resources:
        mem_mb=100000,
        pmem=lambda w, threads: 100000 // threads,
    shell:
        """
        {input.script} {input.r1} {input.r2} {output}
        """


rule estimate_species_depth_from_metagenotype:
    output:
        "data/sp-{species}.{stem}.gtpro.species_depth.tsv",
    input:
        script="scripts/estimate_species_depth_from_metagenotype.py",
        mgen="data/sp-{species}.{stem}.gtpro.mgen.nc",
    params:
        trim=0.05,
    shell:
        "{input.script} {params.trim} {output} {wildcards.species}={input.mgen}"


# NOTE: Hub-rule: Comment out this rule to reduce DAG-building time
# once it has been run for the focal group.
rule concatenate_all_species_depths:
    output:
        "data/group/{group}/{stem}.gtpro.species_depth.tsv",
    input:
        species=lambda w: [
            f"data/group/{w.group}/sp-{species}.{w.stem}.gtpro.species_depth.tsv"
            for species in checkpoint_select_species_with_greater_max_coverage_gtpro(
                group=w.group,
                stem=w.stem,
                cvrg_thresh=0.2,
                num_samples=2,
                require_in_species_group=True,
            )
        ],
    params:
        header="sample	species_id	depth",
    shell:
        """
        echo "{params.header}" > {output}.tmp
        for file in {input.species}
        do
            echo $file >&2
            sed '1,1d' $file
        done >> {output}.tmp
        mv {output}.tmp {output}
        """


rule gather_mgen_group_for_all_species:
    output:
        touch("data/group/{group}/ALL_SPECIES.{stem}.flag"),
    input:
        lambda w: [
            f"data/group/{w.group}/sp-{species}.{w.stem}"
            for species in config["species_group"][w.group]
        ],
    shell:
        "touch {output}"


rule construct_files_for_all_select_species:
    output:
        touch("data/group/{group}/a.{proc_stem}.gtpro.{suffix}.SELECT_SPECIES.flag"),
    input:
        lambda w: [
            f"data/group/{w.group}/sp-{species}.{w.proc_stem}.gtpro.{w.suffix}"
            for species in checkpoint_select_species_with_greater_max_coverage_gtpro(
                group=w.group,
                stem=w.proc_stem,
                cvrg_thresh=0.2,
                num_samples=2,
                require_in_species_group=True,
            )
        ],
