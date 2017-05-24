using Associations
using Base.Test
chars = []
a = """!"#¤%&/()=?*_:;><,.-'§½`'äöåÄÖÅ\\\n \t\b"""
for i in a
    push!(chars, i)
end
getstring(n = 1000) = join(rand(chars, n))

# some base variables
videofolder = "videofolder"

videofiles = Associations.getVideoFiles(videofolder)

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

end

@testset "Load & save" begin
    @testset "VideoFiles" begin
        vfs = Associations.loadVideoFiles(videofolder)

        va = Associations.VideoFile("a.mp4",DateTime("2017-02-28T16:04:47"))
        vb = Associations.VideoFile("b.mp4",DateTime("2017-03-02T15:38:25"))
        @test first(filter(x -> x.file == "a.mp4", vfs)) == va
        @test first(filter(x -> x.file == "b.mp4", vfs)) == vb
    end

    @testset "Association" begin

        x = Associations.loadAssociation(videofolder)
        testlog = joinpath(tempdir(), "testlog")
        isdir(testlog) && rm(testlog, recursive = true)
        mkdir(testlog)
        Associations.save(testlog, x)

        vfs = Associations.loadVideoFiles(videofolder)
        Associations.save(testlog, vfs)

        for f in readdir(joinpath(testlog, "log"))
            @test readstring(joinpath(testlog, "log", f)) == readstring(joinpath(videofolder, "log", f)) 
        end
        isdir(testlog) && rm(testlog, recursive = true)
    end
end

