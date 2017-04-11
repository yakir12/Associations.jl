using Associations
using Base.Test

chars = []
a = """!"#¤%&/()=?*_:;><,.-'§½`'äöåÄÖÅ\\\n """
for i in a
    push!(chars, i)
end
push!(chars, '\t', '\b')
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
    @test Associations.POI() == Associations.POI("", Associations.Point("", 0, 0, 0), Associations.Point("", 0, 0, 0), "")
end

@testset "Run" begin
    da1 = Dict(:comment => getstring(), :name => "a")
    da2 = Dict(:comment => getstring(), :name => "a")
    db = Dict(:comment => getstring(), :name => "b")
    dc = Dict(:comment => getstring(), :name => "c")
    r = Associations.Run[]
    rs = push!(r, da1, da2, db, db, dc)
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
    dicts = repeated(Dict(:comment => getstring(), :name => getstring(3)), nruns)
    push!(r, dicts...)
    a = Associations.Association(p, r, Set())

    @test a.npois == npois
    @test a.nruns == nruns

    push!(a, p...)

    push!(a, dicts...)
    @test a.npois == 2npois
    @test a.nruns == 2nruns

    empty!(a)
    @test a.npois == 0
    @test a.nruns == 0
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
    end
end

@testset "util" begin

    @test all(length(Associations.shorten("a"^x, y)) == (x <= 2y + 1 ? x : 2y + 1) for x = 1:20, y = 1:20)

    n = 20
    for x = 10:10:50
        txt = ["a"^i for i = 1:x]
        d = Associations.shorten(txt, n)
        @test all(length(k) == min(length(v), 2n + 1) for (k,v) in d)
    end

end
