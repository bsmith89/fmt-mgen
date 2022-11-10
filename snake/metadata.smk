# {{{2 Data Configuration

config["mgen"] = pd.read_table("meta/mgen.tsv", index_col="mgen_id")
for mgen_group, d in pd.read_table("meta/mgen_group.tsv").groupby("mgen_group"):
    config["mgen_group"][mgen_group] = d.mgen_id.to_list()

config["figures"]["submission"] = []
