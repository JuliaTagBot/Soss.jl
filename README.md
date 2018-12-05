# Soss

Soss is a library for manipulating source-code representation of probabilistic models.

**Soss IS "PRE-ALPHA" SOFTWARE -- BREAKING CHANGES ARE IMMINENT**

## Probabilistic programming

```julia
julia> normalModel
@model (x,) begin
    μ ~ Normal(0, 5)
    σ ~ HalfCauchy(3)
    x ⩪ Normal(μ, σ) |> iid
end
```

## NUTS sampler

```julia
julia> data = (x=randn(10000),);

julia> nuts(normalModel, data=data)
MCMC, adapting ϵ (75 steps)
0.0019 s/step ...done
MCMC, adapting ϵ (25 steps)
0.0012 s/step ...done
MCMC, adapting ϵ (50 steps)
0.0051 s/step ...done
MCMC, adapting ϵ (100 steps)
0.00095 s/step ...done
MCMC, adapting ϵ (200 steps)
0.00082 s/step ...done
MCMC, adapting ϵ (400 steps)
0.0008 s/step ...done
MCMC, adapting ϵ (50 steps)
0.0011 s/step ...done
MCMC (1000 steps)
step 724 (of 1000), 0.0014 s/step
0.0014 s/step ...done
NUTS_result with samples:
NamedTuple{(:μ, :σ),Tuple{Float64,Float64}}[(μ = 0.00802024, σ = 0.970564), (μ = 0.0161026, σ = 1.00139), (μ = 0.0175141, σ = 0.990568), (μ = 0.0207275, σ = 0.987244), (μ = 0.0197949, σ = 0.995026), (μ = 0.040233, σ = 0.989478), (μ = 0.0310844, σ = 0.997195), (μ = 0.00844086, σ = 0.97504), (μ = 0.0101762, σ = 0.978574), (μ = 0.00557231, σ = 0.999823)  …  (μ = 0.021533, σ = 0.992712), (μ = 0.0212946, σ = 0.988297), (μ = 0.0330258, σ = 0.983934), (μ = 0.00697519, σ = 0.97588), (μ = -0.00422378, σ = 0.986204), (μ = 0.00335039, σ = 0.994075), (μ = 0.00971817, σ = 0.994991), (μ = 0.0104573, σ = 0.9988), (μ = 0.00752986, σ = 0.983179), (μ = 0.00999065, σ = 0.992955)]
```

```julia
julia> mean(getfield.(n.samples,:σ))
0.986755730047984

julia> quantile(getfield.(n.samples,:σ),[0.05,0.5,0.95])
3-element Array{Float64,1}:
 0.9752928158352223
 0.9868497873828663
 0.9983927698927793
```

## Dependency Graphs

```julia
julia> graphEdges(normalModel)
2-element Array{Pair{Symbol,Symbol},1}:
 :μ => :x
 :σ => :x


```julia
julia> lda
@model (α, N, K, V, η) begin
    M = length(N)
    β ~ Dirichlet(repeat([η], V)) |> iid(K)
    θ ~ Dirichlet(repeat([α], K)) |> iid(M)
    z ~ For(1:M) do m
            Categorical(θ[m]) |> iid(N[m])
        end
    w ⩪ For(1:M) do m
            For(1:N[m]) do n
                Categorical(β[(z[m])[n]])
            end
        end
end

julia> g = graph(lda); [(g[e.src,:name] => g[e.dst,:name]) for e in edges(g)]
14-element Array{Pair{Symbol,Symbol},1}:
 :α => :θ
 :N => :w
 :N => :M
 :N => :z
 :M => :w
 :M => :z
 :M => :θ
 :K => :β
 :K => :θ
 :V => :β
 :z => :w
 :β => :w
 :η => :β
 :θ => :z
```
## Coming Soon

Since its initial Stan implementation, "Automatic Differentiation Variational Inference (ADVI)" has become a popular approach to approximate inference. This involves transforming parameters to be over R^n and approximating the posterior with a multivariate normal distribution. There are typically two options for this:
- The covariance can be a diagonal matrix, so the components of the distribution are independent. This is computationally efficient, but is very constrained, and often leads to dramatic underestimation of the variance.
- The covariance can be unconstrained - the only requirement in this case is that it be positive definite. This can result in much tighter bound and a better approximation, but with a great computational expense (quadratic in the dimension of the parameter space).

There's a middle ground that (to my knowledge) has not been explored. The log-likelihood is a function of the parameters that takes the form of a sum of expressions, each involving a subset of the parameters. 

Now, for a multivariate normal, the inverse of the covariance has an interesting property. An element Sigma_ij of this is zero if and only x_i and x_j are independent, given x_{k | k not  in {i,j}}. And this conditional independence property is equivalent to "x_i and x_j do not occur together in any term of the log-likelihood".

Because we're working in terms of expressions, we can get our hands on this relation and use it to specify the form of the inverse covariance. This will allow representation equivalent to the unconstrained version, at greatly reduced computational cost.

This isn't the whole story - to "do it right" would reduce the cost even more but require a different representation. Details of that approach are [here](https://ac.els-cdn.com/S0047259X98917456/1-s2.0-S0047259X98917456-main.pdf?_tid=01eafbd5-e4ce-4b29-bc98-47dfacf99cf2&acdnat=1537155460_c2081b7161fb58932c1551173b5140d5).

- Macro optimization of densities, as in [Passage](https://www.dropbox.com/s/zg2g0cfiin0jdmr/Scherrer%20et%20al.%20-%202014%20-%20Passage%20A%20Parallel%20Sampler%20Generator%20for%20Hierarchical%20Bayesian%20Modeling.pdf)
- Optimization based on exponential families, see [here](https://www.dropbox.com/s/26omxn6zo8gia3u/Scherrer%20-%20Unknown%20-%20An%20Exponential%20Family%20Basis%20for%20Probabilistic%20Programming.pdf?dl=0)

---
Stuff below this point is outdated, updates coming soon

## Old Docs

Here's a simple linear regression model in Soss:

```julia
linReg1D = @model N begin
    # Priors chosen following Gelman(2008)
    α ~ Cauchy(0,10)
    β ~ Cauchy(0,2.5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    x ~ For(1:N) do n 
        Cauchy(0,100)
    end
    ŷ = α + β .* x
    y ~ For(1:N) do n 
        Normal(ŷ[n], σ)
    end
end
```

This produces a Julia expression representing a function:
```julia
:(function (N,)
        α ~ Cauchy(0, 10)
        β ~ Cauchy(0, 2.5)
        σ ~ Truncated(Cauchy(0, 3), 0, Inf)
        x ~ For(((n,)->Cauchy(0, 100)), 1:N)
        ŷ = α + β .* x
        y ~ For(((n,)->Normal(ŷ[n], σ)), 1:N)
    end)
```

Note that the notation after parsing can be slightly different than it originally entered.

Usually, we're not interested in the distribution on `x`, so we condition on it. This removes the distribution declaration, instead passing it as a parameter:

```julia
Main> lr2 = condition(linReg1D, :x)
:(function (N, x)
        α ~ Cauchy(0, 10)
        β ~ Cauchy(0, 2.5)
        σ ~ Truncated(Cauchy(0, 3), 0, Inf)
        ŷ = α + β .* x
        y ~ For(((n,)->Normal(ŷ[n], σ)), 1:N)
    end)
```

We need to be careful with `condition` in cases where the distribution depends on other random values. The implementation will eventually take this into account, but it doens't yet.

From here, we can "run the model" forward, specifying `x` and generating both the parameters and the `y` response. To instead "observe" the `y` values, we need a different approach that conditional. To `observe` a quantity means it is passed as an argument, but the value still affects the distribution:

```julia
Main> lr3 = observe(lr2, :y)
:(function (N, x, y)
        α ~ Cauchy(0, 10)
        β ~ Cauchy(0, 2.5)
        σ ~ Truncated(Cauchy(0, 3), 0, Inf)
        ŷ = α + β .* x
        y <~ For(((n,)->Normal(ŷ[n], σ)), 1:N)
    end)
```

After building a model, you can query it:

```julia
> parameters(lr3)
3-element Array{Symbol,1}:
 :α
 :β
 :σ

Main> supports(lr3)
Dict{Symbol,Any} with 3 entries:
  :α => Distributions.RealInterval(-Inf, Inf)
  :σ => Distributions.RealInterval(0.0, Inf)
  :β => Distributions.RealInterval(-Inf, Inf)
```


Or you can transform it to a form suitable for specialized inference algorithms. For example, a Stan-like approach:

(works for older implementation, but for now this is just a mockup) 
```julia
> logdensity(lr3)
:(function ((N,x,y), θ)
        ℓ = 0.0
        α = θ[1]
        ℓ += logpdf(Cauchy(0, 10), α)
        β = θ[2]
        ℓ += logpdf(Cauchy(0, 2.5), β)
        σ = softplus(θ[3])
        ℓ += abs(σ - θ[3])
        ℓ += logpdf(Truncated(Cauchy(0, 3), 0, Inf), σ)
        ŷ = α + β .* x
        ℓ += logpdf(For(((n,)->Normal(ŷ[n], σ)), 1:N), y)
        return ℓ
    end)
```

## The name

* "Source" (the stuff transformed by Soss), said with a thick Northeastern accent
* Cockney rhyming slang ("sauce pan" rhymes with "[Stan](http://mc-stan.org/)")
* **S**oss is **O**pen **S**ource **S**oftware

