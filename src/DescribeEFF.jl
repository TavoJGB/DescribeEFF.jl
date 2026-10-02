module DescribeEFF

    # External dependencies
    using CSV, DataFrames
    using SparseArrays

    # My dependencies
    # - Reading data
    using DataReader    # https://github.com/TavoJGB/DataReader.jl
    using ReadEFF       # https://github.com/TavoJGB/ReadEFF.jl
    using EconStats     # https://github.com/TavoJGB/EconStats.jl
    using EconFrames    # https://github.com/TavoJGB/EconFrames.jl

    BASE_FOLDER = dirname(@__DIR__)

    # Load dependencies
    include(joinpath(BASE_FOLDER, "src", "dep", "quantiles.jl"))
        export preliminaries_quantile_matrix, quantile_matrix, get_quants, get_avg_quants
    include(joinpath(BASE_FOLDER, "src", "dep", "read_data.jl"))
        export get_eff, read_cpi
    include(joinpath(BASE_FOLDER, "src", "dep", "stats.jl"))
        export get_share_owners, get_share_unemployed
    include(joinpath(BASE_FOLDER, "src", "dep", "types.jl"))

end