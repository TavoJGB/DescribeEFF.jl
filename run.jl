using EconFrames
using DescribeEFF

# Settings
datadir = joinpath(pwd(), "..", "..", "..", "Datos", "EFF")
cpidir = joinpath(pwd(), "..", "..", "..", "Datos", "Inflation")
base_year = 2022

# Load data
eff = get_eff(EFF_YEARS; datadir)
cpi = read_cpi(; datadir=cpidir, filename="ES_cpi_2022.csv", index_var=:index, date_var=:year)

# Account for inflation
#	Special case: income (it corresponds to year before survey)
eff[:hh].income = to_real(eff[:hh].income, cpi, eff[:hh].year.-1, base_year)
eff[:ii].lab_income = to_real(eff[:ii].lab_income, cpi, eff[:ii].year.-1, base_year)
#	Rest of cases
to_real!(eff[:hh], [cpi], base_year; do_warn=false)
to_real!(eff[:ii], [cpi], base_year; do_warn=false)

# Additional variables
# - Employment status
eff[:ii].emp_status = [get_emp_stat(emp, selfemp, unemp) for (emp, selfemp, unemp) in zip(eff[:ii].dummy_emp, eff[:ii].dummy_selfemp, eff[:ii].dummy_unemp)]
# - "Willingness to work" (only available for unemployed)
eff[:ii].dummy_willing_work = [ifelse(coalesce(d_unemp,0.0) == 1.0, ifelse(ismissing(rw), missing,!(rw ∈ [-7;-2;-1])), missing) for (d_unemp, rw) in zip(eff[:ii].dummy_unemp, eff[:ii].reservation_wage)]


#==========================================================================
    UNEMPLOYMENT
==========================================================================#

# Prepare data
# - Use household weights at individual level
active = propagate(eff, :ii, :hh, :weight)
# - Keep only active population
subset!(active, :emp_status => e -> e .∈ Ref(["employed", "unemployed"]))

# Share of "employed" individuals reporting "unemployment" too and vice-versa
combine(active[active.emp_status .== "employed", :], [:year],
	[:dummy_unemp, :weight] => ((d,w) -> weighted_mean(d.==1,w; skipmissing=true)) => :share_unemp
)
combine(active[active.emp_status .== "unemployed", :], [:year],
	[:dummy_emp, :dummy_selfemp, :weight] => ((d,s,w) -> weighted_mean((d.==1) .| (s.==1), w; skipmissing=true)) => :share_emp
)

# Unemployment rates
combine(active, [:year],
	[:emp_status, :weight] => ((status,w) -> round(100*weighted_mean(status .== "unemployed", w; skipmissing=true); digits=1)) => :unemployment_rate,
	[:emp_status, :dummy_search_job, :weight] => ((status,search,w) -> round(100*weighted_mean((status .== "unemployed") .& (search .== 1), w; skipmissing=true); digits=1)) => :active_unemployment_rate,
	[:emp_status, :dummy_willing_work, :weight] => ((status,dww,w) -> round(100*weighted_mean((status .== "unemployed") .& (dww .== 1), w; skipmissing=true); digits=1)) => :willing_unemployment_rate
)



#==========================================================================
    HOUSEHOLDS WEALTH
==========================================================================#

eff_hh = collapse(
	eff, :hh, :ii,
	:lab_income => sum => :lab_income,
	:emp_status => only_head,
	:age => only_head
)

combine(eff_hh, [:year],
	[:asset_home, :assets, :weight] => ((h,t,w) -> weighted_mean(h./t,w; skipmissing=true)) => :ratio_HtoA,
	[:debt_home, :weight] => ((d,w) -> weighted_mean(d.>0,w; skipmissing=true)) => :share_mortgagors,
	[:debts, :weight] => ((d,w) -> weighted_sum(d,w; skipmissing=true)) => :total_debt
)



#==========================================================================
    HOUSEHOLDS GROSS INCOME
==========================================================================#

combine(eff_hh, [:year],
	[:income, :weight] => ((gi,w) -> weighted_sum(gi,w; skipmissing=true)) => :total_gross_income,
	[:income, :weight] => ((gi,w) -> weighted_median(gi,w; skipmissing=true)) => :median_gross_income
)



#==========================================================================
    REAL ESTATE PROPERTIES
==========================================================================#

eff_hh = eff[:hh]
@. eff_hh.n_properties = coalesce(eff_hh.n_properties, 0)

combine(eff_hh, [:year],
	[:n_properties, :weight] => ((n,w) -> weighted_mean(n.>10,w)) => :share_big_re,
	[:n_properties, :weight] => ((n,w) -> weighted_mean(2 .< n .<= 10,w)) => :share_multi_re,
	[:n_properties, :weight] => ((n,w) -> weighted_mean(n.==0,w)) => :share_no_re,
	[:n_properties, :weight] => ((n,w) -> weighted_mean(n[n.>0],w[n.>0])) => :mean_owners_re
)