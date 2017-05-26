using Associations, DataStructures
using Base.Test
# make up some test data
N = 10
chars = []
#a = """!"#¤%&/()=?*_:;><,.-'§½`'äöåÄÖÅ"""
a = """!"¤%&/()=?*_:;><,.-'§½`'äöåÄÖÅ"""
for i in a
    push!(chars, i)
end
#push!(chars, '\\')
#push!(chars, '\n')
#push!(chars, '\t')
#push!(chars, '\b')
getstring() = join(rand(chars, N))
getnice() = join(rand('a':'z', N))
folder = joinpath(tempdir(), tempname())
mkpath(folder)
mkdir(joinpath(folder, "metadata"))
pois = Set(getnice() for i = 1:N)
writecsv(joinpath(folder, "metadata", "poi.csv"), reshape(collect(keys(pois.dict)), (1,N)))
runs = Dict(getnice() => Set(getnice() for i = 1:rand(1:N)) for j = 1:N)
open(joinpath(folder, "metadata", "run.csv"), "w") do o
    for (k, v) in runs
        join(o, [k, v...], ",")
        print(o, '\n')
    end
end

# some base variables
videofolder = "videofolder"

@testset "VideoFile" begin 
    files = Dict("a.mp4" => VideoFile("a.mp4",DateTime("2017-02-28T16:04:47")), "b.mp4" => VideoFile("b.mp4",DateTime("2017-03-02T15:38:25")))
    for (file, vf) in files
        f = joinpath(videofolder, file)
        a = readstring(`$(Associations.exiftool) -q -q $f`)
        @test !isempty(a)
        @test VideoFile(videofolder, file) == vf
    end
    @test sort(getVideoFiles(videofolder)) == sort(collect(keys(files)))
end

@testset "Point" begin
    @test Point("a", 1,1,1) == Point("a", Dates.Second(60*60 + 60 + 1))
end

@testset "POI" begin
    @test POI(name = "a") == POI("a", Point("", 0, 0, 0), Point("", 0, 0, 0), "", "", true)
end

@testset "Run" begin
    @test Run(comment = "a") == Run(Dict{Symbol, String}(), "a", true)
end

@testset "push!" begin
    a = Association()

    push!(a, Run(Dict(Symbol(x) => string(x) for x in 'a':'z'), "a"))
    @test length(a.runs) == 1
    @test a.runs[1].repetition == 1
    push!(a, Run(Dict(Symbol(x) => string(x) for x in 'a':'z'), "b", false))
    @test length(a.runs) == 2
    @test a.runs[2].repetition == 2
    push!(a, Run(Dict(Symbol(x) => string(x) for x in 'b':'z'), "a"))
    @test length(a.runs) == 3
    @test a.runs[3].repetition == 1

    push!(a, POI())
    @test length(a.pois) == 1
    push!(a, POI())
    @test length(a.pois) == 1
    push!(a, POI(name = "a"))
    @test length(a.pois) == 2

    b = OrderedSet{Repetition}()
    push!(b, Run(Dict(Symbol(x) => string(x) for x in 'a':'z'), "a"))
    push!(b, Run(Dict(Symbol(x) => string(x) for x in 'a':'z'), "b", false))

    push!(a, (POI(), b[1]))
    push!(a, (POI(name = "a"), b[2]))

    @test a.associations == Set([(POI(), b[1]), (POI(name = "a"), b[2])])

end

@testset "replace!" begin

    a = Association()
    for i = 1:10
        push!(a, Run(Dict(:a => "a"), string(i)))
    end
    for i = 1:13
        push!(a, POI(name = string(i)))
    end
    for rep = 1:7, poi = 1:10
        push!(a, (POI(name = string(poi)), Repetition(Run(Dict(:a => "a"), string(rep)), rep)))
    end

    replace!(a, POI(name = "4"), POI(name = "a"))

    @test !(POI(name = "4") in a.pois) && POI(name = "a") in a.pois
    @test !(POI(name = "4") in map(first, a.associations)) && POI(name = "a") in map(first, a.associations)

    o = Repetition(Run(Dict(:a => "a"), "2"), 2)
    n = Repetition(Run(Dict(:a => "zzz"), "skldjfh"), 333)
    replace!(a, o, n)

    @test !(o in a.runs) && n in a.runs
    @test !(o in map(last, a.associations)) && n in map(last, a.associations)

end

@testset "delete!" begin

    a = Association()
    n1 = 4
    for i = 1:n1
        push!(a, Run(Dict(:a => "a"), string(i)))
    end
    n2 = 3
    for i = 1:n2
        push!(a, Run(Dict(:b => "a"), string(i)))
    end
    n3 = 4
    for i = 1:n3
        push!(a, POI(name = string(i)))
    end
    for rep = 1:2, poi = 1:2
        push!(a.associations, (POI(name = string(poi)), Repetition(Run(Dict(:a => "a"), string(rep)), rep)))
    end

    delete!(a, Repetition(Run(Dict(:a => "a"), "2"), 2))
    delete!(a, POI(name = "1"))

    b = Association()
    for i in [1,3,4]
        push!(b, Run(Dict(:a => "a"), string(i)))
    end
    n2 = 3
    for i = 1:n2
        push!(b, Run(Dict(:b => "a"), string(i)))
    end
    n3 = 4
    for i = 2:n3
        push!(b, POI(name = string(i)))
    end
    for rep = 1:1, poi = 2:2
        push!(b.associations, (POI(name = string(poi)), Repetition(Run(Dict(:a => "a"), string(rep)), rep)))
    end

    @test a == b

    delete!(a, Repetition(Run(Dict(:c => "a"), "2"), 2))
    delete!(a, POI(name = "z"))

    @test a == b

    delete!(a, (POI(name = "2"), Repetition(Run(Dict(:a => "a"), "1"), 1)))

    @test a.associations == Set{Tuple{POI, Repetition}}()

end

@testset "Load & save" begin

    @testset "VideoFiles" begin
        va = VideoFile("a.mp4",DateTime("2017-02-28T16:04:47"))
        vb = VideoFile("b.mp4",DateTime("2017-03-02T15:38:25"))
        vfs = Set([va, vb])
        save(folder, vfs)
        @test vfs == loadVideoFiles(folder)
    end

    @testset "POI" begin
        a = OrderedSet{POI}()
        for i = 1:4
            push!(a, POI(name = string(i), start = Point(file = string(i), time = Dates.Second(i)), stop = Point(file = string(i), time = Dates.Second(i + 1)), label = string(i), comment = string(i)))
        end
        save(folder, a)

        @test a == loadPOIs(folder)
    end

    @testset "Run" begin
        a = OrderedSet{Repetition}()
        for i = 1:4
            push!(a, Run(Dict(Symbol(j) => string(j) for j = 1:10), string(i)))
        end
        save(folder, a)

        @test a == loadRuns(folder)
    end

    @testset "Association" begin

        a = Association()
        ps = rand(collect(keys(pois.dict)), N)
        for i = 1:N
            r = Dict(Symbol(k) => rand(v) for (k,v) in runs)
            push!(a, Run(r, getstring()))
        end
        for p in ps
            push!(a, POI(name = p))
        end
        for p in rand(collect(keys(a.pois.dict)), N), r in rand(collect(keys(a.runs.dict)), N)
            push!(a, (p, r))
        end
        save(folder, a)

        @test a == loadAssociation(folder)

    end
end

@testset "Other" begin
    a = Association()
    for i = 1:10
        push!(a, Run(Dict(:a => "a"), string(i)))
    end
    for i = 1:13
        push!(a, POI(name = string(i)))
    end
    for rep = 1:7, poi = 1:10
        push!(a, (POI(name = string(poi)), Repetition(Run(Dict(:a => "a"), string(rep)), rep)))
    end

    @test empty!(a) == Association()
    @test isempty(a)

end

