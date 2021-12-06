### A Pluto.jl notebook ###
# v0.17.2

using Markdown
using InteractiveUtils

# ╔═╡ 6021fa5e-d35c-4311-a83c-ac33c665ab02
using HTTP, DelimitedFiles, Plots, IterTools, Combinatorics, Random, Distributions, StatsPlots, Colors, Images

# ╔═╡ a3468efe-08a4-40af-985f-3e9ed3dbdcce
using StatsBase

# ╔═╡ 0091b053-f24e-406c-9b48-04882356ad86
md"""# Lista 1 - IA - 2021/2
Aluno: Victor Silva dos Santos
"""

# ╔═╡ 1a39b939-10f9-4ad3-ac30-3bc2d6934071
md"## Problema 1 -- N-Queens"

# ╔═╡ c1ba8e98-6a4e-45e6-8fcb-4cde49be7fac
function queen_fit(X::Vector{<:Integer})
	D = length(X)
	pos = collect(1:D)
	fit = 0
	for i in pos
		P = X[i]
		for j in (pos .- i)
			if j == 0
				continue
			end
			if P+j == X[i+j] || P-j == X[i+j]
				fit += 1
			end
		end
	end
	fit
end

# ╔═╡ 885f143e-4708-4c37-9cac-0cf99b4f0682
function plot_chess(X::Vector{<:Integer})
	D = length(X)
	M = ones(Integer,D,D)
	for (i,x) in enumerate(X)
		M[x,i] = 0
	end
	Gray.(M)
end

# ╔═╡ 6fbc7788-4736-4346-a08b-a0e0e99f363e
md"## Problema 2 -- Funções teste
### Função esfera"

# ╔═╡ 6fe88ef4-0342-4632-bb98-e3e36e2181e4
md"### Função Rastringin"

# ╔═╡ cf8b1a3f-70d5-490f-83bb-881fe73c0c16
D_11 = 10

# ╔═╡ 0360fb13-f186-40a4-9ee6-cf7fb80dd659
md" ## Algoritmo Genético"

# ╔═╡ 4dab05b9-b1b2-453e-8f2f-09c1632b3d48
# Configurações do algoritmo
struct GAStrategy
    selection
	generation_gap::Real
    crossover
    crossover_prob::Real
    mutation
    mutation_σ::Real
    mutation_prob::Real
    error_tolerance::Real
	strike_tol::Integer
    max_iter::Integer
end

# ╔═╡ e66bff7f-78a1-4317-b7f4-e8287d7a0875
strat_nq = GAStrategy(:ranking, 1, # selection
			   :default, 0.8, # reproduction
			   :default, 2, 0.1, # mutation
				0.1, 20, 1000)

# ╔═╡ 2c217353-803a-4556-a4dc-1cdff404e7be
strat1 = GAStrategy(:ranking, 1, # selection
				   :default, 1, # reproduction
				   :default, 2, 0.05, # mutation
					1e-6, 1, 1000)

# ╔═╡ c0ad6d28-4046-47cc-9ae6-6012b7f21ce9
strat11 = GAStrategy(:ranking, 1, # selection
				   :default, 1, # reproduction
				   :default, 10, 0.04, # mutation
					1e-10, 1, 1000)

# ╔═╡ e1464a65-80b2-415b-9ab2-5547edb12f74
# Classe do Algoritmo Genérico
struct GA
    f::Function
    LB::Array{<:Number}
    UB::Array{<:Number}
    # g::Function
    # h::Function
    strategy::GAStrategy
	objective::Symbol
end

# ╔═╡ 8be18e7b-a996-46e7-946f-ceeb82de8bd1
ga_nq = GA(queen_fit, [1], [1], strat_nq, :min)

# ╔═╡ 4546f9d3-1f6e-4a04-9bc6-8eaf44c4f7eb
function selection_prob(ga::GA, fitness::Vector{<:Real})
	N = length(fitness)
	
	s = ga.strategy
	if s.selection == :proportional
		PS = fitness ./ sum(fitness)
	elseif s.selection == :ranking
		s = rand() + 1
    	idx = sortperm(fitness, rev=true)
		rank = collect(N-1:-1:0)
		rank[idx] = rank
		PS = (2-s)/N .+ 2 .* rank .* (s-1) / (N*(N-1))
	elseif s.selection == :ranking_exp
		idx = sortperm(fitness, rev=true)
		rank = collect(N-1:-1:0)
		rank[idx] = rank
		PS = 1 .- exp.(-rank)
		PS ./= sum(PS)
	else
		PS = (1/N).*ones(N)
	end
	PS
end

# ╔═╡ c9300ca8-205c-44ce-a74d-bc1af03a8a48
function roulette_selection(X::Vector{<:Any}, PS::Vector{<:Real}, λ::Integer)
	[sample(X, pweights(PS)) for i in 1:λ]
end

# ╔═╡ 2a85f4f2-91c8-4e58-a06c-c80cb4b0d7fe
function sus_selection(X::Vector{<:Any}, PS::Vector{<:Real}, λ::Integer)
	r0 = rand()/λ
	r = r0 .+ collect(0:λ-1)./λ
	
	Xr = Vector{typeof(X[1])}(undef, λ)
	a = cumsum(PS)
	for i in 1:λ
		j = 1
		while a[j] <= r[i]
			j += 1
		end
		Xr[i] = X[j]
	end
	Xr
end

# ╔═╡ e1cc07c2-d7d0-4344-8f32-a8b49a357e4b
# Seleção dos indivíduos
function selection(ga::GA, X::Vector{<:Any}, fitness::Vector{<:Real}, age=0)
    N = length(X)
    s = ga.strategy
	
    PS = selection_prob(ga, fitness)
    
    if s.selection == :reduce_by_age
        λ = Integer(ceil(N * (s.generation_gap*(1-age))))
        Xr = sus_selection(X, PS, λ)
    else
		λ = Integer(ceil(N * (s.generation_gap)))
        Xr = sus_selection(X, PS, λ)
    end
    
    Xr
end

# ╔═╡ 9e6ba8fb-8cd5-419c-a2a1-1f000739f8a0
let
Xr = sus_selection(["A","B","C","D","E"],selection_prob(ga_nq, [0.1,0.1,0.1,0.1,0.6]),3)
	
end

# ╔═╡ 63364c03-04db-414b-a58b-c057da38166e
# Cria uma geração aleatória de N indivíduos com D variáveis
function rand_X(ga::GA, D::Integer, N::Integer, T=Float64)
    X = Vector{Vector{T}}(undef, N)
    for i in 1:N
        if T <: AbstractFloat
            v = ga.LB .+ rand(T, D).*(ga.UB.-ga.LB)
		elseif T <: Bool
            v = trunc.(T, ga.LB .+ rand(D).*(ga.UB.-ga.LB))
		else
        end
        X[i] = v
    end
    X
end

# ╔═╡ 4b3b752b-54c1-44ff-baba-232a0a57ff08
evaluate_f(ga::GA, X::Vector{<:Any}) = ga.f.(X)

# ╔═╡ 53044516-2a6f-433c-b2aa-5855a02009c1
md"### Representação por Permutação"

# ╔═╡ d25316bb-a1cb-49e6-bf1b-0bfd7b678791
function rand_X_perm(ga::GA, N::Integer, D::Integer)
	X = Vector{Vector{Integer}}(undef, N)
    for i in 1:N
		v = collect(1:D)
		shuffle!(v)
		X[i] = v
	end
	X
end

# ╔═╡ f8c79585-33aa-4627-bf2d-8deebd9ca779
X0_nq = rand_X_perm(ga_nq, 50, 8)

# ╔═╡ c1692fd0-7154-4757-8e78-01d99795a0e4
function cyclic_grouping(XA::Vector{<:Integer}, XB::Vector{<:Integer})
	D = length(XA)
	arr = []
	
	pos = Set(1:D)
	
	while length(pos) > 0
		
		P0 = minimum(pos)
		
		res = Set([])
		push!(res, P0)
		P = indexin(XA[P0], XB)[1]
		while P != P0
			push!(res, P)
			P = indexin(XA[P], XB)[1]
		end
		
		push!(arr, res)

		pos = setdiff(Set(1:D), union(arr...))
	end
	arr
end

# ╔═╡ 7d4845c3-2043-44cd-83c6-bcebf0a01ea2
# bitflip
function reproduction(ga::GA, XA::Vector{<:Integer}, XB::Vector{<:Integer})

	arr = cyclic_grouping(XA, XB)
	
	D = length(XA)
	childA, childB = Vector{Integer}(undef, D), Vector{Integer}(undef, D)

	if rand() < ga.strategy.crossover_prob
		ord = rand() < 0.5
		for s in arr
			s = [s...]
			if ord
				childA[s], childB[s] = XB[s], XA[s]
			else
				childA[s], childB[s] = XA[s], XB[s]
			end
			ord = ! ord
		end
	end
	
    childA, childB
end

# ╔═╡ 57b6b893-bd08-4b54-ba77-efb1484a768b
function mutate_int!(X::Vector{<:Any}, ga::GA, age=0)
	N = length(X)
    D = length(X[1])
	
	pos = Set(1:D)

	for i in 1:N
		idx1 = rand(pos)
		idx2 =	rand(setdiff(pos, Set(idx1)))
		
		if idx2 < idx1
			i = idx1
			idx1 = idx2
			idx2 = i
		end
		
		p = rand()
		if p < 1/4
			# swap
			# v1 = X[i][idx1]
			# X[i][idx1] = X[i][idx2]
			# X[i][idx2] = v1
		elseif p < 2/4
			# insert
			# vs = X[i][idx1+1:idx2]
			# permute!(vs, [length(vs); collect(1:length(vs)-1)])
			# X[i][idx1+1:idx2] = vs
		elseif p < 3/4
			# scramble
			# vs = X[i][idx1:idx2]
			# shuffle!(vs)
			# X[i][idx1:idx2] = vs
		else
			# invert
			# vs = X[i][idx1:idx2]
			# reverse!(vs)
			# X[i][idx1:idx2] = vs
		end
	end
    X
end


# ╔═╡ 707c0054-5bed-4909-bd2c-f2392948ca0b
md"### Representação por Real"

# ╔═╡ 656f7acb-5b15-44d9-b225-074280b597ea
# crossover aritimético total
function reproduction(ga::GA, XA::Vector{<:Real}, XB::Vector{<:Real})
    if rand() < ga.strategy.crossover_prob
        childA, childB = Float64[], Float64[]
        for (a, b) in zip(XA, XB) 
            α = rand()
            push!(childA, a*α + b*(1-α))
            push!(childB, b*α + a*(1-α))
        end
    else
        childA, childB = XA, XB
    end
    childA, childB
end

# ╔═╡ f6c638ba-0248-4b88-8dce-e0c35608a092
md"### Representação por Bit"

# ╔═╡ e6b953f3-1d3d-4a45-a928-6ee8e283b588
md"## Funções de teste"

# ╔═╡ 38318598-22c4-49a2-900e-6d63fc94add0
md"### Função esfera"

# ╔═╡ 8238c94e-0c62-4cd3-bbc5-b33f08c30914
begin
	f1a = -1400
	f1(X) = sum((X).^2) + f1a
end

# ╔═╡ 0ffcf586-9efb-479a-b984-2b89e3292cba
ga1 = GA(f1, [-100,-100], [100, 100], strat1, :min)

# ╔═╡ 5b6f6cf4-92bb-4a8e-847e-8f7ed3a4e53d
X0_1 = rand_X(ga1, 2, 100, Float64)

# ╔═╡ dd586276-6afe-4016-beb0-fe1bc59b7fb5
let
	x = range(-100,100, length=200)
	y = range(-100,100, length=200)
	xy = map(x->collect(x), Iterators.product(x,y))
	z = f1.(xy)
	
	s = surface(x,y,z)
	c = contour(x,y,z, fill=true)
	plot(s, c; layout=(2,1))
end

# ╔═╡ ae6c7f08-6f7d-49e7-9825-1c4d69dea2dd
md"### Rotated High Conditioned Elliptic Function"

# ╔═╡ 977cc41a-a5c3-4c63-97b0-752b79a8b13e
md"### Rastringin function"

# ╔═╡ d7d5e1b9-3082-4e25-a2d3-8d0e61758289
md"## Helping functions"

# ╔═╡ dad37858-b57a-4496-990e-52190e61a728
@userplot GenPlot2D

# ╔═╡ d6adfd3c-258e-4cb9-ade9-bf31d0e74b19
let
	p = genplot2d(ga1, [X0_1], 1, :fixed)
	plot!(p, title="Primeira Geração")
end

# ╔═╡ bb8e4d4b-04e1-4566-bf96-4860fa4e2735
@recipe function f(gp2D::GenPlot2D)
    ga, Xs, i, mode = gp2D.args
    
    if i > 1
        Xp = Xs[i-1]
        xp, yp = map(x->x[1], Xp), map(x->x[2], Xp)
    end
    
    Xn = Xs[i]
    xn, yn = map(x->x[1], Xn), map(x->x[2], Xn)

	k = 0
	
    if i > 1 && mode == :follow
        minx, miny = minimum([xn;xp]), minimum([yn;yp])
        maxx, maxy = maximum([xn;xp]), maximum([yn;yp])
        x = range(minx - abs(minx*k), maxx + abs(maxx*k), length=100)
        y = range(miny - abs(miny*k), maxy + abs(maxy*k), length=100)
    else
        x = range(ga.LB[1], ga.UB[1], length=100)
        y = range(ga.LB[2], ga.UB[2], length=100)
    end
    xy = map(x->collect(x), Iterators.product(x,y))
    z = ga.f.(xy)
    
    @series begin
        seriestype := :contour
        fill --> false
        x, y, z
    end
    
    if i > 1
        @series begin
            seriestype := :scatter
            label --> false
            markeralpha --> 0.2
            seriescolor --> :blue
            xp, yp
        end
    end
    
    @series begin
        seriestype := :scatter
        label --> "Gen "*string(i)
        seriescolor --> :green
        xn, yn
    end
end


# ╔═╡ 1b1c87ab-9c57-4c6e-9651-b0fc58a352ca
grayencode(n::Integer) = n ⊻ (n >> 1)

# ╔═╡ 6cf2bcc2-0ca3-4946-adaa-21f6c700ccb6
function graydecode(n::Integer)
    r = n
    while (n >>= 1) != 0
        r ⊻= n
    end
    return r
end

# ╔═╡ 761370a2-7cb3-4142-8845-f1bb3fa3b195
# bitflip
function reproduction(ga::GA, XA::Vector{<:BitArray}, XB::Vector{<:BitArray})
    if rand() < ga.strategy.crossover_prob
        childA, childB = Integer[], Integer[]
        for (a, b) in zip(XA, XB)
            r = rand(typeof(a))
            newgenA = (~r & grayencode(a)) | (r & grayencode(b))
            newgenB = (~r & grayencode(b)) | (r & grayencode(a))
            push!(childA, graydecode(newgenA))
            push!(childB, graydecode(newgenB))
        end
    else
        childA, childB = XA, XB
    end
    childA, childB
end

# ╔═╡ ca3796ef-2c3e-486b-b571-d17a278ad1c9
function reproduce_gen(ga::GA, X::Vector{<:Any}, N::Integer)
	
    comb = collect(combinations(1:length(X), 2))
    
    newX = typeof(X)()
    i = 0
    while i < N
        comb = shuffle(comb)
        for k in 1:length(comb)
            if i >= N
                break
            end
            a, b = comb[k]
            childA, childB = reproduction(ga, X[a], X[b])
            push!(newX, childA)
            push!(newX, childB)
            i += 2
        end
    end

	newX
end

# ╔═╡ db6af83c-fc12-43f6-9a4b-459fb659d132
function saturate!(ga, X::Array{<:Any})
	D = length(X)
	for i in 1:D
		if X[i] < ga.LB[i]
			X[i] = ga.LB[i]
		elseif X[i] > ga.UB[i]
			X[i] = ga.UB[i]
		end
	end
	X
end

# ╔═╡ c2a65bb4-ff08-4f0b-ade7-a2a2800bf1cc
function mutate_real!(X::Vector{<:Any}, ga::GA, age=0)
    N = length(X)
	D = length(X[1])

	for i in 1:N
	    if rand() < ga.strategy.mutation_prob
			if ga.strategy.mutation == :reduce_by_age
	        	X[i] += rand(Normal(0, ga.strategy.mutation_σ*(1-age)), D)
			else
				X[i] += rand(Normal(0, ga.strategy.mutation_σ), D)
			end
			saturate!(ga, X[i])
	    end
	end
    X
end

# ╔═╡ 2b2509dd-2ed6-4f9f-9a28-a273d44fe5ea
function mutate!(X::Vector{<:Any}, ga::GA, age=0.0)
	T = typeof(X[1])
	if T <: AbstractFloat
		mutate_real!(X, ga, age)
	else
		mutate_int!(X, ga, age)
	end
end

# ╔═╡ a0092fbe-c792-4e92-b5e3-ad79ef77f5be
function bitarr_to_int(arr, val = 0)
    v = 2^(length(arr)-1)
    for i in eachindex(arr)
        val += v*arr[i]
        v >>= 1
    end
    return val
end

# ╔═╡ c18e2efb-8710-4a67-9689-ede1fe877b2d
function mutate!(X::Vector{<:BitArray}, ga::GA, age=0)
    D = length(X)
    T = typeof(X[1])
    
#     if rand() > ga.strategy.mutation_prob
        for i in 1:D
        
            Δ = trunc(T, ga.LB[i] - ga.UB[i])
        
            x = X[i] + Δ
            
            flip_arr = [0; rand(ndigits(typemin(Int8), base=2)-1) .< ga.strategy.mutation_prob]
            flip = bitarr_to_int(flip_arr)
            
            x = graydecode(grayencode(x) ⊻ trunc(T, flip))
            
            X[i] = x - Δ
        end
	saturate!(ga, X)
#     end
    X
end

# ╔═╡ 60fe54f6-837e-4cac-903a-3db308f71d8f
function evolve_gen(ga::GA, X::Vector{<:Any}, fitness::Vector{<:Real}, age=0)
    N = length(X)
    D = length(X[1])
    s = ga.strategy

	# realiza a seleção dos indivíduos para reprodução
    Xred = selection(ga, X, fitness, age)

	# reprodução dos indivíduos
	newX = reproduce_gen(ga, Xred, N)
	
	# mutação dos indivíduos
	# for i in 1:N
	# 	newX[i] = mutate!(ga, newX[i], age)
	# end
    mutate!(newX, ga, age)
    newX
end

# ╔═╡ c9a7c598-230b-41fa-a992-747c7e640da9
# roda o algoritmo
function run_ga(ga::GA, X0::Vector{<:Any})

	# minimizar ou maximizar a função
    sig = ga.objective == :max ? 1 : -1

	# primeira avaliação de fitness
    fitness0 = evaluate_f(ga, X0) .* sig
    new_Xs = X0
    fitness = fitness0
    
    i = 1

	# histórico
    xhist = [new_Xs]
    fithist = [fitness]

	strike = 0
	
    while i <= ga.strategy.max_iter
		
		# executa os passos de evolução da geração atual
        new_Xs = evolve_gen(ga, new_Xs, fitness, i/ga.strategy.max_iter)
        
        push!(xhist, new_Xs)
        
        fitness0 = fitness

		# avalia a nova geração
        fitness = evaluate_f(ga, new_Xs) .* sig
        
        push!(fithist, fitness)

		# verifica a convergência
        e = abs.(maximum(fitness) .- maximum(fitness0))./abs.(maximum(fitness0))
        
        if e < ga.strategy.error_tolerance
			strike += 1
			if strike >= ga.strategy.strike_tol
            	break
			end
		else
			strike = 0
        end
        
        i += 1
    end
    
    xhist, fithist.*sig
end

# ╔═╡ 5b4588fa-c73b-49b8-a3ec-9b0b30259f40
xs_nq, fits_nq = run_ga(ga_nq, X0_nq)

# ╔═╡ eabccb4b-9890-428c-9d43-dbab84fd08cc
let
	
	md"""
	Número de gerações: $(length(fits_nq))
	
	Quantidade de avaliações da função objetivo: $(length(fits_nq)*length(X0_nq))
	
	Valor mínimo encontrado: $(minimum(fits_nq[end]))
	"""
end

# ╔═╡ b6790a2a-bc7a-4e16-ab8c-e998d2af5c31
plot_chess(xs_nq[end][argmin(fits_nq[end])])

# ╔═╡ 40e315bf-49fb-4e80-91c2-5ee237c08d0a
xs_1, fits_1 = run_ga(ga1, X0_1)

# ╔═╡ e598a7e2-a059-47a3-bee5-23890fc4994b
md"""
Número de gerações: $(length(fits_1))

Quantidade de avaliações da função objetivo: $(length(fits_1)*length(X0_1))

Valor mínimo encontrado: $(minimum(fits_1[end]))

Valor mínimo da função: $(f1a)
"""

# ╔═╡ 7b4128c7-fff5-4bf0-b673-46a7ebc818dd
let
	p1 = genplot2d(ga1, xs_1, length(fits_1), :fixed)
	plot!(p1, title="Geração final (visão global)")
end

# ╔═╡ cd96b5e2-d4ae-4b25-aecd-efc02ee96f49
let
	p1 = genplot2d(ga1, xs_1, length(fits_1), :follow)
	plot!(p1, title="Geração final (visão local)")
end

# ╔═╡ 75ecda46-8672-4a2d-a051-28132373ab23
begin
	anim1 = @animate for i in 1:length(xs_1)
		genplot2d(ga1, xs_1, i, :fixed)
	end
	md"#### Evolução"
end

# ╔═╡ c305594a-a65d-4c2f-8177-99a334cbebd6
let
	gif(anim1, fps=10)
end

# ╔═╡ fc1541fc-892c-49a4-80e0-3829c3dde0d7
boxplot(map( x -> (x .- f1a), fits_1), title="Dispersão do fitness por geração", legend=nothing)

# ╔═╡ 9838e06b-a30f-426f-b319-51bcf54d45d7
function bitarray_to_int(ga::GA, ba::BitArray)
    l = length(ba)
    k = sum(ba .* (2 .^ (l-1:-1:0)))
    ga.LI + (ga.LS - ga.LI)*k/(2^l - 1)
end

# ╔═╡ 03cf431e-3d6c-4167-81bf-9df45ce6182b
function int_to_bitarray(ga::GA, x::Integer)
    parse.(Bool, split(bitstring(x), ""))
end

# ╔═╡ e253199e-5051-11ec-3956-7b8b6cf4c1e8
shift = let
	res = HTTP.get("https://raw.githubusercontent.com/dmolina/cec2013single/master/cec2013single/cec2013_data/shift_data.txt")
	readdlm(res.body)
end

# ╔═╡ 44589478-3a1e-455a-b218-2025451d5111
o(i, N) = shift[i,1:N]

# ╔═╡ 2f85fd12-08c5-46d1-8542-8183775f0f25
MD2 = let
	res = HTTP.get("https://raw.githubusercontent.com/dmolina/cec2013single/master/cec2013single/cec2013_data/M_D2.txt")
	readdlm(res.body)
end

# ╔═╡ b184e8dd-d960-4d4e-8108-067f561cf88a
M(i) = MD2[i*2-1:i*2,:]

# ╔═╡ 5dd415b1-ae92-4e59-9fc5-7060dde228ab
function sign(xi)
    if xi < 0
        return -1.
    elseif xi == 0
        return 0.
    else
        return 1.
    end
end     

# ╔═╡ 885400f7-32af-42d6-b7a7-68000228263b

function x_hat(xi)
    if xi == 0
        return 0.
    end
    log(abs(xi))
end
   

# ╔═╡ a9f4ec4e-4590-4114-a920-11b2654e0991
 
function c1f(xi)
    if xi > 0
        return 10.
    end
    5.5
end


# ╔═╡ 57a57096-97a9-4ead-97bb-03cc5dcf6bd7

function c2f(xi)
    if xi > 0
        return 7.9
    end
    3.1
end
    


# ╔═╡ 19d4d957-b1db-4c09-b808-3eee5463ff68

function Tosz(X)
    xh = x_hat.(X)
    c1, c2 = c1f.(X), c2f.(X)
    D = length(X)
    X[1] = sign(X[1]) * exp(xh[1] + 0.049 * (sin(c1[1]*xh[1]) + sin(c2[1]*xh[1])))
    X[D] = sign(X[D]) * exp(xh[D] + 0.049 * (sin(c1[D]*xh[D]) + sin(c2[D]*xh[D])))
    X
end


# ╔═╡ db52ac1e-8c29-4858-8422-bd72eb77545c
begin
	f2a = -1300
	
	function f2(X)
	    r = 0
	    D = length(X)
	    Z = Tosz(M(1)*(X))
	    i = 1:D
	    sum(1e6.^((i.-1)./(D.-1)).*Z.^2) .+ f2a
	end
end

# ╔═╡ c5671266-8ac9-45a1-aab8-2337abe20d3c
let
	x = range(-100,100, length=200)
	y = range(-100,100, length=200)
	xy = map(x->collect(x), Iterators.product(x,y))
	z = f2.(xy)
	
	s = surface(x,y,z)
	c = contour(x,y,z; fill=true)
	plot(s, c; layout=(2,1))
end

# ╔═╡ 78f05a6c-c7f9-450a-ae86-3b1777c89dc3

function Tasz(X, β)
    D = length(X)
    for i in 1:D
        if X[i] > 0
            X[i] = X[i]^(1 + β*sqrt(X[i])*(i-1)/(D-1))
        end
    end
    X
end


# ╔═╡ 68738ecd-2769-4b8a-be9b-a138745ca829
function Α(α, D)
    m = zeros(D, D)
    for i in 1:D
        m[i,i] = α^((i-1)/(2*(D-1)))
    end
    m
end

# ╔═╡ a235d168-76cb-4c1e-8d72-80b55a13b97d
begin
	f11a = -400
	
	function f11(X)
	    D = length(X)
	    Z = Α(10, D) * Tasz(Tosz(5.12.*X./100), 0.2)
	    sum(Z.^2 .- 10cos.(2π*Z) .+ 10) .+ f11a
	end
end

# ╔═╡ 0e6096a2-28b5-42a0-9ca6-c01268e1b28f
ga11 = GA(f11, -100 .* ones(D_11), 100 .* ones(D_11), strat11, :min)

# ╔═╡ b13ba3ef-f838-4758-ae04-59e8be85e250
X0_11 = rand_X(ga11, D_11, 200, Float64)

# ╔═╡ f162da3d-0165-4417-9f88-0ceb31869f88
xs_11, fits_11 = run_ga(ga11, X0_11)

# ╔═╡ d9dec120-048b-49fc-9684-ce28c69a56e1
md"""
Número de gerações: $(length(fits_11))

Quantidade de avaliações da função objetivo: $(length(fits_11)*length(X0_11))

Valor mínimo encontrado: $(minimum(fits_11[end]))

Valor mínimo da função: $(f11a)
"""

# ╔═╡ 86c88686-aa8a-4ba1-8f28-bc265562203e
let
	x = range(-5,30, length=200)
	y = range(-40,0, length=200)
	xy = map(x->collect(x), Iterators.product(x,y))
	z = f11.(xy)
	
	s = surface(x,y,z;)
	c = contour(x,y,z; fill=true)
plot(s, c; layout=(2,1))
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
Combinatorics = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
DelimitedFiles = "8bb1440f-4735-579b-a4ab-409b98df4dab"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
Images = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
IterTools = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
StatsPlots = "f3b207a7-027a-5e70-b257-86293d7955fd"

[compat]
Colors = "~0.12.8"
Combinatorics = "~1.0.2"
Distributions = "~0.25.34"
HTTP = "~0.9.17"
Images = "~0.25.0"
IterTools = "~1.3.0"
Plots = "~1.24.2"
StatsBase = "~0.33.13"
StatsPlots = "~0.14.29"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "485ee0867925449198280d4af84bdb46a2a404d0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.0.1"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[Arpack]]
deps = ["Arpack_jll", "Libdl", "LinearAlgebra"]
git-tree-sha1 = "2ff92b71ba1747c5fdd541f8fc87736d82f40ec9"
uuid = "7d9fca2a-8960-54d3-9f78-7d1dccf2cb97"
version = "0.4.0"

[[Arpack_jll]]
deps = ["Libdl", "OpenBLAS_jll", "Pkg"]
git-tree-sha1 = "e214a9b9bd1b4e1b4f15b22c0994862b66af7ff7"
uuid = "68821587-b530-5797-8361-c406ea357684"
version = "3.5.0+3"

[[ArrayInterface]]
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "265b06e2b1f6a216e0e8f183d28e4d354eab3220"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.2.1"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "d127d5e4d86c7680b20c35d40b503c74b9a39b5e"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.4"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "f885e7e7c124f8c92650d61b9477b9ac2ee607dd"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.1"

[[ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "9a1d594397670492219635b35a3d830b04730d62"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.1"

[[Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "75479b7df4167267d75294d14b58244695beb2ac"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.14.2"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "3f1f500312161f1ae067abe07d13b40f78f32e07"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.8"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "681ea870b918e7cff7111da58791d7f718067a19"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.2"

[[CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[DataValues]]
deps = ["DataValueInterfaces", "Dates"]
git-tree-sha1 = "d88a19299eba280a6d062e135a43f00323ae70bf"
uuid = "e7dc6d0d-1eca-5fa6-8ad6-5aecde8b7ea5"
version = "0.4.13"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "837c83e5574582e07662bbbba733964ff7c26b9d"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.6"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "7f3bec11f4bcd01bc1f507ebce5eadf1b0a78f47"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.34"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "84f04fe68a3176a583b864e492578b9466d87f1e"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "3fe985505b4b667e1ae303c9ca64d181f09d5c05"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.1.3"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "463cb335fa22c4ebacfd1faba5fde14edb80d96c"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.4.5"

[[FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "2db648b6712831ecb333eae76dbfd1c156ca13bb"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.2"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8756f9935b7ccc9064c6eef0bff0ad643df733a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.7"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "30f2b340c2fff8410d89bfcdc9c0a6dd661ac5f7"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.62.1"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fd75fa3a2080109a2c0ec9864a6e14c60cca3866"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.62.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "74ef6288d071f58033d54fd6708d4bc23a8b8972"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+1"

[[Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "1c5a84319923bea76fa145d49e93aa4394c73fc2"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.1"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Graphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "92243c07e786ea3458532e199eb3feee0e7e08eb"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.4.1"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "c54b581a83008dc7f292e205f4c409ab5caa0f04"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.10"

[[ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[ImageContrastAdjustment]]
deps = ["ImageCore", "ImageTransformations", "Parameters"]
git-tree-sha1 = "0d75cafa80cf22026cea21a8e6cf965295003edc"
uuid = "f332f351-ec65-5f6a-b3d1-319c6670881a"
version = "0.3.10"

[[ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "9a5c62f231e5bba35695a20988fc7cd6de7eeb5a"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.3"

[[ImageDistances]]
deps = ["Distances", "ImageCore", "ImageMorphology", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "7a20463713d239a19cbad3f6991e404aca876bda"
uuid = "51556ac3-7006-55f5-8cb3-34580c88182d"
version = "0.2.15"

[[ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "15bd05c1c0d5dbb32a9a3d7e0ad2d50dd6167189"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.1"

[[ImageIO]]
deps = ["FileIO", "Netpbm", "OpenEXR", "PNGFiles", "TiffImages", "UUIDs"]
git-tree-sha1 = "a2951c93684551467265e0e32b577914f69532be"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.5.9"

[[ImageMagick]]
deps = ["FileIO", "ImageCore", "ImageMagick_jll", "InteractiveUtils"]
git-tree-sha1 = "ca8d917903e7a1126b6583a097c5cb7a0bedeac1"
uuid = "6218d12a-5da1-5696-b52f-db25d2ecc6d1"
version = "1.2.2"

[[ImageMagick_jll]]
deps = ["JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pkg", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "1c0a2295cca535fabaf2029062912591e9b61987"
uuid = "c73af94c-d91f-53ed-93a7-00f77d67a9d7"
version = "6.9.10-12+3"

[[ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "36cbaebed194b292590cba2593da27b34763804a"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.8"

[[ImageMorphology]]
deps = ["ImageCore", "LinearAlgebra", "Requires", "TiledIteration"]
git-tree-sha1 = "5581e18a74a5838bd919294a7138c2663d065238"
uuid = "787d08f9-d448-5407-9aad-5290dd7ab264"
version = "0.3.0"

[[ImageQualityIndexes]]
deps = ["ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "OffsetArrays", "Statistics"]
git-tree-sha1 = "1d2d73b14198d10f7f12bf7f8481fd4b3ff5cd61"
uuid = "2996bd0c-7a13-11e9-2da2-2f5ce47296a9"
version = "0.3.0"

[[ImageSegmentation]]
deps = ["Clustering", "DataStructures", "Distances", "Graphs", "ImageCore", "ImageFiltering", "ImageMorphology", "LinearAlgebra", "MetaGraphs", "RegionTrees", "SimpleWeightedGraphs", "StaticArrays", "Statistics"]
git-tree-sha1 = "36832067ea220818d105d718527d6ed02385bf22"
uuid = "80713f31-8817-5129-9cf8-209ff8fb23e1"
version = "1.7.0"

[[ImageShow]]
deps = ["Base64", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "d0ac64c9bee0aed6fdbb2bc0e5dfa9a3a78e3acc"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.3"

[[ImageTransformations]]
deps = ["AxisAlgorithms", "ColorVectorSpace", "CoordinateTransformations", "ImageBase", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "b4b161abc8252d68b13c5cc4a5f2ba711b61fec5"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.9.3"

[[Images]]
deps = ["Base64", "FileIO", "Graphics", "ImageAxes", "ImageBase", "ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "ImageIO", "ImageMagick", "ImageMetadata", "ImageMorphology", "ImageQualityIndexes", "ImageSegmentation", "ImageShow", "ImageTransformations", "IndirectArrays", "IntegralArrays", "Random", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "TiledIteration"]
git-tree-sha1 = "35dc1cd115c57ad705c7db9f6ef5cc14412e8f00"
uuid = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
version = "0.25.0"

[[Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "87f7662e03a649cffa2e05bf19c303e168732d3e"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.2+0"

[[IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[IntegralArrays]]
deps = ["ColorTypes", "FixedPointNumbers", "IntervalSets"]
git-tree-sha1 = "00019244715621f473d399e4e1842e479a69a42e"
uuid = "1d092043-8f09-5a30-832f-7509e371ab51"
version = "0.1.2"

[[IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "61aa005707ea2cebf47c8d780da8dc9bc4e0c512"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.4"

[[IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "3cc368af3f110a767ac786560045dceddfc16758"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.3"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLD2]]
deps = ["DataStructures", "FileIO", "MacroTools", "Mmap", "Pkg", "Printf", "Reexport", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "46b7834ec8165c541b0b5d1c8ba63ec940723ffb"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.15"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "591e8dc09ad18386189610acafb970032c519707"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.3"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a8f4f279b6fa3c3c4f1adadd78a621b13a506bce"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.9"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "5455aef09b40e5020e1520f551fa3135040d4ed0"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2021.1.1+2"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[MetaGraphs]]
deps = ["Graphs", "JLD2", "Random"]
git-tree-sha1 = "2af69ff3c024d13bde52b34a2a7d6887d4e7b438"
uuid = "626554b9-1ddb-594c-aa3c-2596fe9399a5"
version = "0.7.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[MultivariateStats]]
deps = ["Arpack", "LinearAlgebra", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "8d958ff1854b166003238fe191ec34b9d592860a"
uuid = "6f286f6a-111f-5878-ab1e-185364afe411"
version = "0.8.0"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "16baacfdc8758bc374882566c9187e785e85c2f0"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.9"

[[Netpbm]]
deps = ["FileIO", "ImageCore"]
git-tree-sha1 = "18efc06f6ec36a8b801b23f076e3c6ac7c3bf153"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.2"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Observables]]
git-tree-sha1 = "fe29afdef3d0c4a8286128d4e45cc50621b1e43d"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.4.0"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "043017e0bdeff61cfbb7afeb558ab29536bbb5ed"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.8"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "923319661e9a22712f24596ce81c54fc0366f304"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.1+0"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "ee26b350276c51697c9c2d88a072b339f9f03d73"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.5"

[[PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "6d105d40e30b635cfed9d52ec29cf456e27d38f8"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.12"

[[PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "646eed6f6a5d8df6708f15ea7e02a7a2c4fe4800"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.10"

[[Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "a7a7e1a88853564e551e4eba8650f8c38df79b37"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.1.1"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "b084324b4af5a438cd63619fd006614b3b20b87b"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.15"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun"]
git-tree-sha1 = "93f484f18848234ac2c1387c7e5263f840cdafe3"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.24.2"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "afadeba63d90ff223a6a48d2009434ecee2ec9e8"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.1"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[Quaternions]]
deps = ["DualNumbers", "LinearAlgebra"]
git-tree-sha1 = "adf644ef95a5e26c8774890a509a55b7791a139f"
uuid = "94ee1d12-ae83-5a48-8b1c-48b8ff168ae0"
version = "0.4.2"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[Ratios]]
deps = ["Requires"]
git-tree-sha1 = "01d341f502250e81f6fec0afe662aa861392a3aa"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.2"

[[RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[RegionTrees]]
deps = ["IterTools", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "4618ed0da7a251c7f92e869ae1a19c74a7d2a7f9"
uuid = "dee08c22-ab7f-5625-9660-a9af2021b33f"
version = "0.3.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[Rotations]]
deps = ["LinearAlgebra", "Quaternions", "Random", "StaticArrays", "Statistics"]
git-tree-sha1 = "dbf5f991130238f10abbf4f2d255fb2837943c43"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.1.0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "f45b34656397a1f6e729901dc9ef679610bd12b5"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.8"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays", "Test"]
git-tree-sha1 = "a6f404cc44d3d3b28c793ec0eb59af709d827e4e"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.2.1"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f0bccf98e16759818ffc5d97ac3ebf87eb950150"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.8.1"

[[StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "e7bc80dc93f50857a5d1e3c8121495852f407e6a"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.4.0"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "0f2aa8e32d511f758a2ce49208181f7733a0936a"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.1.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2bb0cb32026a66037360606510fca5984ccc6b75"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.13"

[[StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "bedb3e17cc1d94ce0e6e66d3afa47157978ba404"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.14"

[[StatsPlots]]
deps = ["Clustering", "DataStructures", "DataValues", "Distributions", "Interpolations", "KernelDensity", "LinearAlgebra", "MultivariateStats", "Observables", "Plots", "RecipesBase", "RecipesPipeline", "Reexport", "StatsBase", "TableOperations", "Tables", "Widgets"]
git-tree-sha1 = "d6956cefe3766a8eb5caae9226118bb0ac61c8ac"
uuid = "f3b207a7-027a-5e70-b257-86293d7955fd"
version = "0.14.29"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableOperations]]
deps = ["SentinelArrays", "Tables", "Test"]
git-tree-sha1 = "e383c87cf2a1dc41fa30c093b2a19877c83e1bc1"
uuid = "ab02a1b2-a7df-11e8-156e-fb1833f50b87"
version = "1.2.0"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "fed34d0e71b91734bf0a7e10eb1bb05296ddbcd0"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "c342ae2abf4902d65a0b0bf59b28506a6e17078a"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.5.2"

[[TiledIteration]]
deps = ["OffsetArrays"]
git-tree-sha1 = "5683455224ba92ef59db72d10690690f4a8dc297"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.3.1"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "66d72dc6fcc86352f01676e8f0f698562e60510f"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.23.0+0"

[[Widgets]]
deps = ["Colors", "Dates", "Observables", "OrderedCollections"]
git-tree-sha1 = "80661f59d28714632132c73779f8becc19a113f2"
uuid = "cc8bc4a8-27d6-5769-a93b-9d913e69aa62"
version = "0.6.4"

[[WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╠═6021fa5e-d35c-4311-a83c-ac33c665ab02
# ╟─0091b053-f24e-406c-9b48-04882356ad86
# ╟─1a39b939-10f9-4ad3-ac30-3bc2d6934071
# ╠═c1ba8e98-6a4e-45e6-8fcb-4cde49be7fac
# ╠═885f143e-4708-4c37-9cac-0cf99b4f0682
# ╠═e66bff7f-78a1-4317-b7f4-e8287d7a0875
# ╠═8be18e7b-a996-46e7-946f-ceeb82de8bd1
# ╠═f8c79585-33aa-4627-bf2d-8deebd9ca779
# ╠═5b4588fa-c73b-49b8-a3ec-9b0b30259f40
# ╟─eabccb4b-9890-428c-9d43-dbab84fd08cc
# ╠═b6790a2a-bc7a-4e16-ab8c-e998d2af5c31
# ╟─6fbc7788-4736-4346-a08b-a0e0e99f363e
# ╠═2c217353-803a-4556-a4dc-1cdff404e7be
# ╠═0ffcf586-9efb-479a-b984-2b89e3292cba
# ╠═5b6f6cf4-92bb-4a8e-847e-8f7ed3a4e53d
# ╟─d6adfd3c-258e-4cb9-ade9-bf31d0e74b19
# ╠═40e315bf-49fb-4e80-91c2-5ee237c08d0a
# ╟─e598a7e2-a059-47a3-bee5-23890fc4994b
# ╟─7b4128c7-fff5-4bf0-b673-46a7ebc818dd
# ╟─cd96b5e2-d4ae-4b25-aecd-efc02ee96f49
# ╟─75ecda46-8672-4a2d-a051-28132373ab23
# ╟─c305594a-a65d-4c2f-8177-99a334cbebd6
# ╟─fc1541fc-892c-49a4-80e0-3829c3dde0d7
# ╟─6fe88ef4-0342-4632-bb98-e3e36e2181e4
# ╠═c0ad6d28-4046-47cc-9ae6-6012b7f21ce9
# ╠═cf8b1a3f-70d5-490f-83bb-881fe73c0c16
# ╠═0e6096a2-28b5-42a0-9ca6-c01268e1b28f
# ╠═b13ba3ef-f838-4758-ae04-59e8be85e250
# ╠═f162da3d-0165-4417-9f88-0ceb31869f88
# ╟─d9dec120-048b-49fc-9684-ce28c69a56e1
# ╟─0360fb13-f186-40a4-9ee6-cf7fb80dd659
# ╠═e1464a65-80b2-415b-9ab2-5547edb12f74
# ╠═4dab05b9-b1b2-453e-8f2f-09c1632b3d48
# ╠═c9a7c598-230b-41fa-a992-747c7e640da9
# ╠═60fe54f6-837e-4cac-903a-3db308f71d8f
# ╠═2b2509dd-2ed6-4f9f-9a28-a273d44fe5ea
# ╠═e1cc07c2-d7d0-4344-8f32-a8b49a357e4b
# ╠═4546f9d3-1f6e-4a04-9bc6-8eaf44c4f7eb
# ╠═c9300ca8-205c-44ce-a74d-bc1af03a8a48
# ╠═2a85f4f2-91c8-4e58-a06c-c80cb4b0d7fe
# ╠═a3468efe-08a4-40af-985f-3e9ed3dbdcce
# ╠═9e6ba8fb-8cd5-419c-a2a1-1f000739f8a0
# ╠═ca3796ef-2c3e-486b-b571-d17a278ad1c9
# ╠═63364c03-04db-414b-a58b-c057da38166e
# ╠═4b3b752b-54c1-44ff-baba-232a0a57ff08
# ╟─53044516-2a6f-433c-b2aa-5855a02009c1
# ╠═d25316bb-a1cb-49e6-bf1b-0bfd7b678791
# ╠═7d4845c3-2043-44cd-83c6-bcebf0a01ea2
# ╠═c1692fd0-7154-4757-8e78-01d99795a0e4
# ╠═57b6b893-bd08-4b54-ba77-efb1484a768b
# ╟─707c0054-5bed-4909-bd2c-f2392948ca0b
# ╠═656f7acb-5b15-44d9-b225-074280b597ea
# ╠═c2a65bb4-ff08-4f0b-ade7-a2a2800bf1cc
# ╟─f6c638ba-0248-4b88-8dce-e0c35608a092
# ╟─761370a2-7cb3-4142-8845-f1bb3fa3b195
# ╠═c18e2efb-8710-4a67-9689-ede1fe877b2d
# ╟─e6b953f3-1d3d-4a45-a928-6ee8e283b588
# ╟─38318598-22c4-49a2-900e-6d63fc94add0
# ╠═8238c94e-0c62-4cd3-bbc5-b33f08c30914
# ╟─dd586276-6afe-4016-beb0-fe1bc59b7fb5
# ╟─ae6c7f08-6f7d-49e7-9825-1c4d69dea2dd
# ╠═db52ac1e-8c29-4858-8422-bd72eb77545c
# ╟─c5671266-8ac9-45a1-aab8-2337abe20d3c
# ╟─977cc41a-a5c3-4c63-97b0-752b79a8b13e
# ╠═a235d168-76cb-4c1e-8d72-80b55a13b97d
# ╟─86c88686-aa8a-4ba1-8f28-bc265562203e
# ╟─d7d5e1b9-3082-4e25-a2d3-8d0e61758289
# ╟─dad37858-b57a-4496-990e-52190e61a728
# ╠═bb8e4d4b-04e1-4566-bf96-4860fa4e2735
# ╟─1b1c87ab-9c57-4c6e-9651-b0fc58a352ca
# ╟─6cf2bcc2-0ca3-4946-adaa-21f6c700ccb6
# ╟─db6af83c-fc12-43f6-9a4b-459fb659d132
# ╠═a0092fbe-c792-4e92-b5e3-ad79ef77f5be
# ╠═9838e06b-a30f-426f-b319-51bcf54d45d7
# ╠═03cf431e-3d6c-4167-81bf-9df45ce6182b
# ╠═e253199e-5051-11ec-3956-7b8b6cf4c1e8
# ╟─44589478-3a1e-455a-b218-2025451d5111
# ╟─2f85fd12-08c5-46d1-8542-8183775f0f25
# ╟─b184e8dd-d960-4d4e-8108-067f561cf88a
# ╟─5dd415b1-ae92-4e59-9fc5-7060dde228ab
# ╟─885400f7-32af-42d6-b7a7-68000228263b
# ╟─a9f4ec4e-4590-4114-a920-11b2654e0991
# ╟─57a57096-97a9-4ead-97bb-03cc5dcf6bd7
# ╟─19d4d957-b1db-4c09-b808-3eee5463ff68
# ╟─78f05a6c-c7f9-450a-ae86-3b1777c89dc3
# ╟─68738ecd-2769-4b8a-be9b-a138745ca829
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
