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


@testset "exiftool" begin 
    for file in videofiles
        f = joinpath(videofolder, file)
        a = readstring(`$(Associations.exiftool) -q -q $f`)
        @test !isempty(a)
    end
    vf = [Associations.VideoFile(videofolder, file) for file in videofiles]
    a = [Associations.VideoFile("a.mp4",DateTime("2017-02-28T16:04:47")), Associations.VideoFile("b.mp4",DateTime("2017-03-02T15:38:25"))]
    files = ["a.mp4", "b.mp4"]
    for file in videofiles
        ai = filter(x -> x.file == file, a)
        v = filter(x -> x.file == file, vf)
        @test ai[1] == v[1]
    end
end

@testset "POI" begin
    @test Associations.POI() == Associations.POI("", Associations.Point("", 0, 0, 0), Associations.Point("", 0, 0, 0), "", "", true)
end

@testset "Run" begin
    @test Associations.Run() == Associations.Run(Dict(:nothing => "nothing"), "", true)

    da1 = Dict(:comment => "ss", :name => "a")
    da2 = Dict(:comment => "ss", :name => "a")
    db = Dict(:comment => "ss", :name => "b")
    dc = Dict(:comment => "ss", :name => "c")
    rs = Associations.OrderedSet{Associations.Repetition}()
    for d in [da1, da2, db, db, dc]
        push!(rs, Associations.Run(d, getstring()))
    end
    for (name, rep) in zip(["a", "b", "c"], [2, 2, 1])
        n = reduce((y,x) -> max(x.run.metadata[:name] == name ? x.repetition : 0, y), 0, rs)
        @test n == rep
    end

    delete!(rs, rs[1])
    @test length(rs) == 4
end

@testset "Association" begin

    npois = 3
    nruns = 4
    p = Associations.OrderedSet{Associations.POI}()
    for i = 1:npois
        pp = Associations.POI(name = string(i))
        push!(p, pp)
    end
    r = Associations.OrderedSet{Associations.Repetition}()
    for i = 1:nruns
        push!(r, Associations.Run(Dict(:name => getstring(3)), getstring(i)))
    end
    a = Associations.Association(p, r, Associations.Set{Tuple{Associations.POI,Associations.Repetition}}())

    @test length(a.pois) == npois
    @test length(a.runs) == nruns

    p = Associations.OrderedSet{Associations.POI}()
    for i = 1:npois
        pp = Associations.POI(name = string(i), label = string(i))
        push!(p, pp)
    end
    push!(a, p...)

    @test length(a.pois) == 2npois

    for i = 1:nruns
        push!(a, Associations.Run(Dict(:name => getstring(3)), getstring(i)))
    end

    @test length(a.runs) == 2nruns

    delete!(a, p[1])

    @test length(a.pois) == 2npois - 1

    delete!(a, r[1])

    @test length(a.runs) == 2nruns - 1

    empty!(a)

    @test a == Associations.Association()

    @test isempty(a)

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

@testset "util" begin

    @test all(length(Associations.shorten("a"^x, y)) == (x <= 2y + 1 ? x : 2y + 1) for x = 0:8, y = 0:3)

    function testitdifferent(x, y)
        txt = [join(select('a':'z', 1:i)) for i = 1:x]
        Associations.shorten(txt, y)
    end
    function testitsame(x, y)
        txt = ["a"^i for i = 1:x]
        Associations.shorten(txt, y)
    end

    @test all(all(length(k) <= x for (k,v) in testitsame(x, y)) for x = 1:9, y = 1:3)

    @test all(all(length(k) == min(length(v), 2y + 1) for (k,v) in testitdifferent(x, y)) for x = 1:9, y = 1:3)

    @test_throws SystemError Associations.openit("thisfiledoesnotexist.666")

    #@test Associations.openit(joinpath(videofolder, "a.mp4"))

    d = Dict(string(x) => string(x) for x in 'a':'z')
    @test Associations.findshortfile("b", d) == "b"
    @test_throws ErrorException Associations.findshortfile("bad", d) == "b"

end



