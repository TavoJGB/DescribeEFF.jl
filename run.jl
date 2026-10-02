using EconFrames
using DescribeEFF

# Settings
datadir = joinpath(pwd(), "..", "..", "..", "Datos", "EFF")
cpidir = joinpath(pwd(), "..", "..", "..", "Datos")

# Load data
eff = get_eff(2022; datadir)
cpi=read_cpi(; datadir=cpidir, filename="ES_cpi_2022.csv", index_var=:index, date_var=:year)