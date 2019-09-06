using Reexport

@reexport using DataFrames
using MLStyle
using Distributions

EmptyNTtype = NamedTuple{(),T} where T<:Tuple


export xform

# function xform(m::Model{EmptyNTtype, B}) where {B}
#     return xform(m,NamedTuple())    
# end

@generated function xform(_m::Model{A,B}, _args::A, _data) where {A,B} 
    type2model(_m) |> sourceXform |> loadvals(_args, NamedTuple())
end

export sourceXform

function sourceXform(m::Model{A,B}) where {A,B}
    _m = canonical(m)

    proc(_m, st::Assign)        = :($(st.x) = $(st.rhs))
    proc(_m, st::Return)     = nothing
    proc(_m, st::LineNumber) = nothing
    # proc(_m, st::Observe)    = :($(st.x) = rand($(st.rhs)))
    
    function proc(_m, st::Sample)
        @q begin
                $(st.x) = rand($(st.rhs))
                _t = xform($(st.rhs))

                _result = merge(_result, ($(st.x)=_t,))
        end
    end

    wrap(kernel) = @q begin
        _result = NamedTuple()
        $kernel
        as(_result)
    end

    buildSource(_m, proc, wrap) |> flatten


end




function xform(d)
    if hasmethod(support, (typeof(d),))
        return asTransform(support(d)) 
    end
end

function asTransform(supp:: RealInterval) 
    (lb, ub) = (supp.lb, supp.ub)

    (lb, ub) == (-Inf, Inf) && (return asℝ)
    (lb, ub) == (0.0,  Inf) && (return asℝ₊)
    (lb, ub) == (0.0,  1.0) && (return as𝕀)
    error("asTransform($supp) not yet supported")
end

# export xform
# xform(::Normal)       = asℝ
# xform(::Cauchy)       = asℝ
# xform(::Flat)         = asℝ

# xform(::HalfCauchy)   = asℝ₊
# xform(::HalfNormal)   = asℝ₊
# xform(::HalfFlat)     = asℝ₊
# xform(::InverseGamma) = asℝ₊
# xform(::Gamma)        = asℝ₊
# xform(::Exponential)  = asℝ₊

# xform(::Beta)         = as𝕀
# xform(::Uniform)      = as𝕀




function xform(d::For)
    # allequal(d.f.(d.θs)) && 
    return as(Array, xform(d.f(d.θs[1])), size(d.θs)...)
    
    # TODO: Implement case of unequal supports
    @error "xform: Unequal supports not yet supported"
end

function xform(d::iid)
    as(Array, xform(d.dist), d.size...)
end
