#===========================================================================
    STRUCTS
===========================================================================#

abstract type QuantileType end
struct BasicQuantile <: QuantileType end
struct TopQuantile <: QuantileType end
struct BottomQuantile <: QuantileType end



#===========================================================================
    THRESHOLDS
===========================================================================#

get_qs(::BasicQuantile, divs; current_q::Int=1) = (0:size(divs,1)) .+ current_q
get_qs(::TopQuantile, divs; current_q::Int=1) = (0:size(divs,1)-1) .+ current_q
get_qs(::BottomQuantile, divs; current_q::Int=1) = (0:size(divs,1)-1) .+ current_q



#===========================================================================
    QUANTILE MATRIX
===========================================================================#

# Function to assign individuals to quantiles and return vectors with
# indexes and values
# 1. QuantileType-specific functions
function _quantile_vecs!(
    rows::Vector{<:Int}, cols::Vector{<:Int}, vals::AbstractVector{<:Real},
    ::TopQuantile, ::Any, ind_U, wgt, N::Int;
    qs  # index of each quantile
)::Nothing
    for (iq, qq) in pairs(qs)
        n = N-ind_U[iq]+1
        append!(rows, fill(qq, n))
        append!(cols, ind_U[iq]:N)
        append!(vals, [wgt[iq]; ones(Float64, n-1)])
    end
    return nothing
end
function _quantile_vecs!(
    rows::Vector{<:Int}, cols::Vector{<:Int}, vals::AbstractVector{<:Real},
    ::BottomQuantile, ::Any, ind_U, wgt, ::Int;
    qs  # index of each quantile
)::Nothing
    for (iq, qq) in pairs(qs)
        n = ind_U[iq]
        append!(rows, fill(qq, n))
        append!(cols, 1:n)
        append!(vals, [ones(Float64, n-1); 1-wgt[iq]])
    end
    return nothing
end

# Function to assign individuals to quantiles and return vectors with
# indexes and values
# 1. General functions
function quantile_vecs!(
    rows::Vector{<:Int}, cols::Vector{<:Int}, vals::AbstractVector{<:Real},
    qtype::QuantileType, divs::AbstractVector{<:Real}, cum_distr::AbstractVector{<:Real};
    qs=get_qs(qtype, divs)
)::Nothing
    # Find frontiers and weights
    ind_L, ind_U, wgt = get_weights(Extrapolate(), divs, cum_distr)
    # Assign quantiles
    _quantile_vecs!(rows, cols, vals, qtype, ind_L, ind_U, wgt, size(cum_distr,1); qs)
    return nothing
end
function quantile_vecs!(
    rows::Vector{<:Int}, cols::Vector{<:Int}, vals::AbstractVector{<:Real},
    qtype::BasicQuantile, divs::AbstractVector{<:Real}, cum_distr::AbstractVector{<:Real};
    qs=get_qs(qtype, divs)
)::Nothing
    edges = [0.0; divs; 1.0]
    distr_prev = [0.0; cum_distr[1:(end-1)]]
    mass = cum_distr .- distr_prev
    for qq in 1:length(qs)
        lo = max.(distr_prev, edges[qq])
        hi = min.(cum_distr, edges[qq+1])
        mass_in_q = hi - lo
        ind = @. (mass_in_q>0) & (mass>0)
        append!(rows, fill(qq, sum(ind)))
        append!(cols, findall(ind))
        append!(vals, mass_in_q[ind] ./ mass[ind])   # fraction of agent assigned to quantile qq
    end
    return nothing
end
function quantile_vecs(
    qtype::QuantileType, divs::AbstractVector{<:Real}, cum_distr::AbstractVector{<:Real};
    kwargs...
)
    # Preliminaries
    rows = Int[]
    cols = Int[]
    vals = Float64[]
    quantile_vecs!(rows, cols, vals, qtype, divs, cum_distr; kwargs...)
    return rows, cols, vals
end

# Prepare quantile matrix
function preliminaries_quantile_matrix(; N_quants::Int=5, top::Real=0.0, range_labels::Bool=false)
    divs = range(0,1;length=N_quants+1)[2:end-1] |> collect
    if range_labels
        edges = vcat(0, Int.(divs*100), 100)
        labs = ["P$(edges[i])-$(edges[i+1])" for i in 1:(length(edges)-1)]
    else
        labs = ["Q$(i)" for i in 1:N_quants] 
    end
    if 0 < top < 1
        labs = [labs; "T$(round(Int,100*top))"]
        divs = [divs, [1-top]]
        qtypes = [BasicQuantile(), TopQuantile()]
        quantmat_kwargs=Dict(:qtypes=>qtypes)
    else
        quantmat_kwargs=Dict()
    end
    return divs, labs, quantmat_kwargs
end

# Matrix to help with the computation of quantiles
function quantile_matrix(
    quant_divs::AbstractVector{<:Real}, varvals::AbstractVector{<:Real}, distr::AbstractVector{<:Real};
    qtype::QuantileType=BasicQuantile()
)::SparseMatrixCSC
    nq = size(quant_divs,1)+1
    # Rank nodes from lower to higher values
    iSort = sortperm(varvals)
    # Cumulative distribution
    sorted_distr = distr[iSort]
    cum_distr = cumsum(sorted_distr) / sum(sorted_distr)
    # Matrix with indicators of quantiles
    rows, cols, vals = quantile_vecs(qtype, quant_divs, cum_distr)
    # Recover the original order
    return sparse(rows, iSort[cols], vals, nq, size(varvals,1))
end
function quantile_matrix(
    vecvec_divs::Vector{<:AbstractVector{<:Real}}, var::AbstractVector{<:Real}, distr::AbstractVector{<:Real};
    qtypes::Vector{<:QuantileType}
)::SparseMatrixCSC
    # Preliminaries
    current_q = 1
    rows = Int[]
    cols = Int[]
    vals = Float64[]
    # Rank nodes from lower to higher values
    iSort = sortperm(var)
    # Cumulative distribution
    sorted_distr = distr[iSort]
    cum_distr = cumsum(sorted_distr) / sum(sorted_distr)
    # Matrix with indicators of quantiles
    for (divs, qtype) in zip(vecvec_divs, qtypes)
        # Update quantile indexes
        qs=get_qs(qtype, divs; current_q)
        current_q += size(qs,1)
        # Get quantile vectors
        quantile_vecs!(rows, cols, vals, qtype, divs, cum_distr; qs)
    end
    # Recover the original order
    N_rows = sum(length.(vecvec_divs)) .+ count(isa.(qtypes, BasicQuantile))
    return sparse(rows, iSort[cols], vals, N_rows, size(var,1))
end
# Method to get nq equally-sized quantiles:
function quantile_matrix(nq::Int, args...)::SparseMatrixCSC
    quant_divs = range(0,1;length=nq+1)[2:end-1] |> collect
    return quantile_matrix(quant_divs, args...)
end



#===========================================================================
    LABELS
===========================================================================#

# Default labels
function default_labels(quantmat::AbstractArray, distr::AbstractVector{<:Real})
    # Get the quantiles
    q = [0; round.(Int, 100*cumsum(quantmat*distr))]
    # Get the labels
    return ["P_$(q[i-1])-$(q[i])" for i in ((1:size(quantmat,1)) .+ 1)]
end
function default_labels(quantmat::AbstractArray)
    # Get the quantiles
    q = range(0,100;length=(1+size(quantmat,1)))
    # Get the labels
    return ["P_$(q[i-1])-$(q[i])" for i in ((1:size(quantmat,1)) .+ 1)]
end



#===========================================================================
    STATS
===========================================================================#

# Shares by quantile
get_quants(quantmat::SparseMatrixCSC, var::AbstractVector{<:Real}, distr::AbstractVector{<:Real}) = quantmat*(var .* distr) / dot(var,distr)
get_quants(arg_divs, var::AbstractVector{<:Real}, distr::AbstractVector{<:Real}; kwargs...) = get_quants(quantile_matrix(arg_divs, var, distr; kwargs...), var, distr)

# Average by quantile
get_avg_quants(quantmat::AbstractArray, var::AbstractVector, distr::AbstractVector{<:Real}) = quantmat*(var .* distr) ./ (quantmat*distr)
get_avg_quants(arg_divs, var::AbstractVector, distr::AbstractVector{<:Real}; kwargs...) = get_avg_quants(quantile_matrix(arg_divs, var, distr; kwargs...), var, distr)



#===========================================================================
    TRANSITIONS BETWEEN QUANTILES
    Summarises the transition matrix Q by quantiles. It leads to
    substantial approximation errors.
===========================================================================#

# function quantile_transition_matrix(quant_mat::SparseMatrixCSC, Q::SparseMatrixCSC, distr::AbstractVector{<:Real})
#     quant_distr = quant_mat' .* distr
#     return quant_mat * Q * (quant_distr ./ sum(quant_distr,dims=1))
# end