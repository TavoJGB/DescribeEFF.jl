#==========================================================================
    READING EFF (i)
    Main function
==========================================================================#

function get_eff(args...; kwargs...)
    # Read EFF into EconFrames
    eff_ii, eff_hh, eff_re = read_eff_into_econframes(args...; kwargs...)
    # Replace missing income values with zeros
    @. eff_ii.lab_income_direct = coalesce(eff_ii.lab_income_direct, 0)
    @. eff_ii.lab_income_inkind = coalesce(eff_ii.lab_income_inkind, 0)
    # Additional variables
    eff_ii.lab_income = @. eff_ii.lab_income_direct + eff_ii.lab_income_inkind
    # Monetary variables
    curr = NominalEUR()
    monetary_variable!(eff_hh, [:income; :wealth; :asset_home; :debt_home], curr, AnyGood())
    monetary_variable!(eff_ii, [:lab_income_direct, :lab_income_inkind, :lab_income], curr, AnyGood())
    # Return EconSet
    return EconSet(Dict(:ii => eff_ii, :hh => eff_hh, :re => eff_re), (:ii, :hh) => [:year, :hid, :imputation], (:re, :hh) => [:year, :hid, :imputation])
end



#==========================================================================
    READING EFF (ii)
    Helper functions.
==========================================================================#

# Raw reading into DataFrames
function read_eff_into_df(
    years::AbstractVector{Int}=[2002:3:2020;2022], imputations::AbstractVector{Int}=1:5;
    datadir::String=joinpath("data", "eff"), varlists_dir::String="var_lists",
    varlist_filename::String="eff_vars.csv",
    comment::String="#", kwargs...
)
    identifier_ranges = (:year => years, :imputation => imputations)
    return read_eff(datadir, identifier_ranges; varlists_dir, varlist_filename, comment, kwargs...)
end

# Move EFF data from DataFrames into an EconSet
function read_eff_into_econframes(
    years::AbstractVector{Int}, args...;
    date_var::Union{Symbol,String}=:year, kwargs...
)
    length(years) == 1 && return read_eff_into_econframes(only(years), args...; kwargs...)
    # Read EFF
    eff_df_ii, eff_df_hh, eff_df_re = read_eff_into_df(years, args...; kwargs...)
    # Create EconFrames
    eff_ii = EconRepeatedCrossSection(eff_df_ii, EFF(), Individual(), Annual(), date_var; imputation_var=:imputation)
    eff_hh = EconRepeatedCrossSection(eff_df_hh, EFF(), Household(), Annual(), date_var; imputation_var=:imputation)
    eff_re = EconRepeatedCrossSection(eff_df_re, EFF(), RealEstate(), Annual(), date_var; imputation_var=:imputation)
    return eff_ii, eff_hh, eff_re
end
function read_eff_into_econframes(year::Int, args...; kwargs...)
    # Read EFF
    eff_df_ii, eff_df_hh, eff_df_re = read_eff_into_df([year], args...; kwargs...)
    # Create EconFrames
    eff_ii = EconCrossSection(eff_df_ii, EFF(), Individual(), year-1; imputation_var=:imputation)
    eff_hh = EconCrossSection(eff_df_hh, EFF(), Household(), year-1; imputation_var=:imputation)
    eff_re = EconCrossSection(eff_df_re, EFF(), RealEstate(), year-1; imputation_var=:imputation)
    return eff_ii, eff_hh, eff_re
end



#==========================================================================
    READ CPI
==========================================================================#

function read_cpi(;
    index_var::Symbol=:cpi, date_var::Symbol=:date, good_type::GoodType=AnyGood(),
    filename::String="cpi.csv",
    datadir::String=joinpath(BASE_FOLDER, "data"),
    comment::String="#"
)
    filepath = joinpath(datadir, filename)
    raw_cpi = CSV.read(filepath, DataFrame; comment)
    return CPI(raw_cpi[!, date_var], raw_cpi[!, index_var], good_type)
end
