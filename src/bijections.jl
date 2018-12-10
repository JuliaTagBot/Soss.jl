using Distributions
using StatsFuns
using TransformVariables



# export link, invlink
#
# link(d,x) = x
# invlink(d,x) = x

export fromℝ, toℝ




function fromℝ(d::iid) 
    as(Array, fromℝ(d.dist), d.shape)
end

realDists = [Normal,Cauchy, Flat]

for dist in realDists
    expr = quote
        fromℝ(::typeof($dist())) = asℝ
        # toℝ(d::typeof($dist())) = inverse(asℝ₊)
    end
    eval(expr)
end


positiveDists = [HalfCauchy,Exponential,Gamma,HalfFlat]

for dist in positiveDists
    expr = quote
        fromℝ(d::typeof($dist())) = asℝ₊
        # toℝ(d::typeof($dist())) = inverse(asℝ₊)
    end
    eval(expr)
end

# for dist in positiveDists
#     expr = quote
#         link(d::typeof($dist()),x) = log(x)
#         invlink(d::typeof($dist()),x) = exp(x)
#     end
#     eval(expr)
# end

unitIntervalDists = [Beta]
for dist in unitIntervalDists
    expr = quote
        fromℝ(d::typeof($dist())) = as𝕀
        toℝ(d::typeof($dist())) = inverse(as𝕀)
    end
    eval(expr)
end
