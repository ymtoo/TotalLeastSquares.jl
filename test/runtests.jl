using Random, Statistics, LinearAlgebra, Test, FillArrays, Printf, TotalLeastSquares
Random.seed!(0)


@testset "TotalLeastSquares" begin

    @testset "TLS" begin
        @info "Testing TLS"
        x   = randn(3)
        A   = randn(50,3)
        σa  = 1
        σy  = 0.01
        An  = A + σa*randn(size(A))
        y   = A*x
        yn  = y + σy*randn(size(y))
        Qaa = σa^2*Eye(prod(size(A)))
        Qay = 0Eye(prod(size(A)),length(y))
        Qyy = σy^2*Eye(prod(size(y)))

        x̂ = An\yn
        @printf "Least squares error: %25.3e %10.3e %10.3e, Norm: %10.3e\n" (x-x̂)... norm(x-x̂)
        @test norm(x-x̂) < 1

        x̂ = wls(An,yn,Qyy)
        @printf "Weigthed Least squares error: %16.3e %10.3e %10.3e, Norm: %10.3e\n" (x-x̂)... norm(x-x̂)
        @test norm(x-x̂) < 1

        x̂ = tls(An,yn)
        @printf "Total Least squares error: %19.3e %10.3e %10.3e, Norm: %10.3e\n" (x-x̂)... norm(x-x̂)
        @test norm(x-x̂) < 1

        x̂ = wtls(An,yn,Qaa,Qay,Qyy,iters=10)
        @printf "Weighted Total Least squares error: %10.3e %10.3e %10.3e, Norm: %10.3e\n" (x-x̂)... norm(x-x̂)
        println("----------------------------")
        @test norm(x-x̂) < 1

        @test tls(An,yn) ≈ tls!([An yn], size(An,2))

        rowC = rowcovariance([[σa^2*Eye(3) zeros(3); zeros(1,3) σy^2] for _ in 1:50])
        @test rowC[1] ≈ Qaa
        @test rowC[2] ≈ Qay
        @test rowC[3] ≈ Qyy

    end


    @testset "Robust PCA" begin
        @info "Testing Robust PCA"
        D = [0.462911    0.365901  0.00204357    0.692873    0.935861;
        0.0446199    0.108606   0.0664309   0.0736707    0.264429;
        0.320581    0.287788    0.073133    0.188872    0.526404;
        0.356266    0.197536 0.000718338    0.513795    0.370094;
        0.677814    0.011651    0.818047   0.0457694    0.471477]

        A = [0.462911   0.365901  0.00204356   0.345428   0.623104;
        0.0446199  0.108606  0.0429271    0.0736707  0.183814;
        0.320581   0.203777  0.073133     0.188872   0.472217;
        0.30725    0.197536  0.000717701  0.201626   0.370094;
        0.234245   0.011651  0.103622     0.0457694  0.279032]

        E = [0.0        0.0        0.0        0.347445  0.312757 ;
        0.0        0.0        0.0235038  0.0       0.0806151;
        0.0        0.0840109  0.0        0.0       0.0541868;
        0.0490157  0.0        6.5061e-7  0.312169  0.0      ;
        0.443569   0.0        0.714425   0.0       0.192445]

        Â, Ê = rpca(D, nonnegE=true, nonnegA=true, verbose=true)

        @test Â ≈ A atol=1.0e-6
        @test Ê ≈ E atol=1.0e-6
        @test norm(D - (Â + Ê))/norm(D) < sqrt(eps())


        Â, Ê = rpca(D, nonnegE=false, nonnegA=false, verbose=true)
        @test norm(D - (Â + Ê))/norm(D) < sqrt(eps())

    end

@testset "rtls" begin
    @info "Testing rtls"
    passes = map(1:1000) do _
        x   = randn(3)
        A   = randn(50,3)
        σ   = 5
        An  = A + σ*randn(size(A)) .* (rand(size(A)...) .< 0.1)
        y   = A*x
        yn  = y + σ*randn(size(y)) .* (rand(size(y)...) .< 0.1)

        AA  = [An yn]
        Ah,Eh = rpca(AA, verbose=false)

        sum(abs2, Ah - [A y])/sum(abs2,[A y]) < sum(abs2, AA - [A y])/sum(abs2,[A y])
    end
    @test mean(passes) > 0.9

    passes = map(1:1000) do _
        x   = randn(3)
        A   = randn(50,3)
        σ   = 50
        An  = A + σ*randn(size(A)) .* (rand(size(A)...) .< 0.1)
        y   = A*x
        yn  = y + σ*randn(size(y)) .* (rand(size(y)...) .< 0.1)

        x̂t = tls(An,yn)
        x̂r = rtls(An,yn)

        norm(x-x̂r) < norm(x-x̂t)
    end
    @test mean(passes) > 0.8

end

@testset "soft toeplitz" begin
    function istoeplitz(A)
        for i = size(A,2)-1:-1:(-size(A,1)+1)
            di = diagind(A,i)
            all(==(A[di[1]]), A[di]) || return false
        end
        true
    end
    @info "Testing soft toeplitz"
    A = [1 2 3 4;
         5 1 2 3;
         6 5 1 2;
         7 6 5 1;
         8 7 6 5]
    @test istoeplitz(A)
     An = A + 0.1randn(size(A))
     @test !istoeplitz(An)
     Anc = copy(An)
     TotalLeastSquares.soft_toeplitz!(An, 0.1)
     @test sum(abs2,An-A) < sum(abs2,Anc-A)

     An = -A + 0.1randn(size(A))
     Anc = copy(An)
     TotalLeastSquares.soft_toeplitz!(An, 0.1)
     @test sum(abs2,An+A) < sum(abs2,Anc+A)


    An = Float64.(A)
    An[diagind(A,0)] .+= 0.1
    An[diagind(A,-1)] .-= 0.1
    Anc = copy(An)
    A1,E1 = rpca(An, verbose=true, nukeA=false)
    A2,E2 = rpca(An, verbose=true, nukeA=false, toeplitz=true)
    @test sum(abs2,A2-A) < sum(abs2,A1-A)

    passes = map(1:500) do _
        y = randn(100)
        A = zeros(95,5)
        for i in 0:size(A,1)-1
            di = diagind(A,-i)
            for di in di
                A[di] = y[i+2]
            end
        end
        for i in 1:size(A,2)-1
            di = diagind(A,i)
            for di in di
                A[di] = y[5-i+1]
            end
        end
        @test istoeplitz(A)
        A1,E1 = rpca(A, verbose=false, nukeA=false)
        A2,E2 = rpca(A, verbose=false, nukeA=false, toeplitz=true)
        @test istoeplitz(A2)
        @test istoeplitz(E2)
        mean(abs2,A2-A) < mean(abs2,A1-A)
    end
    @show mean(passes)
    @test mean(passes) > 0.78


    passes = map(1:10) do _
        y = randn(1000)
        A = zeros(950,50)
        for i in 0:size(A,1)-1
            di = diagind(A,-i)
            for di in di
                A[di] = y[i+2]
            end
        end
        for i in 1:size(A,2)-1
            di = diagind(A,i)
            for di in di
                A[di] = y[50-i+1]
            end
        end
        @test istoeplitz(A)
        A1,E1 = rpca(A, verbose=false, nukeA=false)
        A2,E2 = rpca(A, verbose=false, nukeA=false, toeplitz=true)
        @test istoeplitz(A2)
        @test istoeplitz(E2)
        mean(abs2,A2-A) < mean(abs2,A1-A)
    end
    @show mean(passes)
    @test mean(passes) >= 0.5

end


end
