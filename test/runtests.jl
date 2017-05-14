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


# test the 
@testset "exiftool" begin 
    for file in videofiles
        f = joinpath(videofolder, file)
        a = readstring(`$(Associations.exiftool) -q -q $f`)
        @test !isempty(a)
    end
    vf = [Associations.VideoFile(videofolder, file) for file in videofiles]
    a = [Associations.VideoFile("a.mp4",[DateTime("2017-02-28T16:04:47")]), Associations.VideoFile("b.mp4",[DateTime("2017-03-02T15:38:25")])]
    files = ["a.mp4", "b.mp4"]
    for file in videofiles
        ai = filter(x -> x.file == file, a)
        v = filter(x -> x.file == file, vf)
        @test ai == v
    end
end

@testset "POI" begin
    @test Associations.POI() == Associations.POI("", Associations.Point("", 0, 0, 0), Associations.Point("", 0, 0, 0), "", "", true)
end

@testset "Run" begin
    da1 = Dict(:comment => getstring(), :name => "a")
    da2 = Dict(:comment => getstring(), :name => "a")
    db = Dict(:comment => getstring(), :name => "b")
    dc = Dict(:comment => getstring(), :name => "c")
    rs = Associations.Run[]
    for d in [da1, da2, db, db, dc]
        push!(rs, d)
    end
    for (name, rep) in zip(["a", "b", "c"], [2, 2, 1])
        n = reduce((y,x) -> max(x.metadata[:name] == name ? x.repetition : 0, y), 0, rs)
        @test n == rep
    end
end

@testset "Association" begin
    npois = 3
    nruns = 4
    p = fill(Associations.POI(), npois)
    r = Associations.Run[]
    dicts = [Dict(:comment => getstring(), :name => getstring(3)) for i = 1:nruns]
    for d in dicts
        push!(r, d)
    end
    a = Associations.Association(p, r, Set())

    @test a.npois == npois
    @test a.nruns == nruns

    push!(a, p...)

    push!(a, dicts...)
    @test a.npois == 2npois
    @test a.nruns == 2nruns

    empty!(a)
    #@test a.npois == 0
    #@test a.nruns == 0

    @test a == Associations.Association()# = Association(POI[], Run[], Set())

end

@testset "Load & save" begin
    @testset "VideoFiles" begin
        vfs = Associations.loadVideoFiles(videofolder)

        va = Associations.VideoFile("a.mp4",[DateTime("1977-06-01T00:00:00")])
        vb = Associations.VideoFile("b.mp4",[DateTime("2017-03-02T15:38:25")])
        @test first(filter(x -> x.file == "a.mp4", vfs)) == va
        @test first(filter(x -> x.file == "b.mp4", vfs)) == vb
    end

    @testset "Association" begin

        x = Associations.loadAssociation(videofolder)
        testlog = "testlog"
        isdir(testlog) && rm(testlog, recursive = true)
        mkdir(testlog)
        Associations.save(testlog, x)

        vfs = Associations.loadVideoFiles(videofolder)
        Associations.save(testlog, vfs)

        for f in readdir(joinpath(testlog, "log"))
            #@test readstring(joinpath(testlog, "log", f)) == readstring(joinpath(videofolder, "log", f)) 
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

end
