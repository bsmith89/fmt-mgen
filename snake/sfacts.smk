rule start_ipython_sfacts:
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        ipython
        """


rule start_shell_sfacts:
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        bash
        """


use rule install_jupyter_kernel_default as install_jupyter_kernel_sfacts with:
    params:
        name="sfacts",
    conda:
        "conda/sfacts.yaml"


# NOTE: Comment out this rule to speed up DAG-building time
rule load_metagenotype_from_merged_gtpro:
    output:
        "{stem}.gtpro.mgen.nc",
    input:
        "{stem}.gtpro.tsv.bz2",
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        python3 -m sfacts load --gtpro-metagenotype {input} {output}
        """


rule filter_metagenotype:
    output:
        "{stem}.filt-poly{poly}-cvrg{cvrg}.mgen.nc",
    input:
        "{stem}.mgen.nc",
    wildcard_constraints:
        poly="[0-9]+",
        cvrg="[0-9]+",
    params:
        poly=lambda w: float(w.poly) / 100,
        cvrg=lambda w: float(w.cvrg) / 100,
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        python3 -m sfacts filter_mgen \
                --min-minor-allele-freq {params.poly} \
                --min-horizontal-cvrg {params.cvrg} \
                {input} {output}
        """
