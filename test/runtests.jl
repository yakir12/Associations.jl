using Associations, DataStructures
using Base.Test, Base.Dates

# some base variables
videofolder = joinpath(Pkg.dir("Associations"), "test", "videofolder")

# make up some test data

folder = mktempdir()
mkdir(joinpath(folder, "metadata"))
pois = Set(["name1", "name2", "name3"])
writecsv(joinpath(folder, "metadata", "poi.csv"), reshape(collect(keys(pois.dict)), (1,3)))
runs = Dict("a" => ["a", "b", "q"], "b" => ["a", "c"], "c" => ["b"])
open(joinpath(folder, "metadata", "run.csv"), "w") do o
    for (k, v) in runs
        join(o, [k, v...], ",")
        print(o, '\n')
    end
end


A = Association()
P1 = POI("name1", Point("file1.mp4", Second(0)), Point("file1.mp4", Second(1)), "label", "comment")
P2 = POI("name2", Point("file1.mp4", Second(1)), Point("file2.mp4", Second(2)), "other label", "also a comment")
P3 = POI("name3", Point("file3.mp4", Second(4)), Point("file3.mp4", Second(6)), "other label", "also a comment")
R1 = Run(Dict(:a => "a", :b => "a", :c => "b"), "a comment")
R2 = Run(Dict(:a => "b", :b => "c", :c => "b"), "a comment")
R3 = Run(Dict(:a => "b", :b => "c", :c => "b"), "this is comment of a replicate")
R4 = Run(Dict(:a => "q", :b => "c", :c => "b"), "bla")

target_vfs = OrderedSet([VideoFile("a.mp4",DateTime("2017-02-28T16:04:47")), VideoFile("b.mp4",DateTime("2017-03-02T15:38:25"))])

@testset "VideoFile" begin 

    @test getVideoFiles(videofolder) == target_vfs

end

@testset "Point" begin
    @test Point("a", 1,1,1) == Point("a", Dates.Second(60*60 + 60 + 1))
end

@testset "POI" begin
    @test POI(name = "a") == POI("a", Point("", 0, 0, 0), Point("", 0, 0, 0), "", "")
    @test_throws AssertionError POI("name1", Point("file1.mp4", Second(1)), Point("file1.mp4", Second(0)), "label", "comment")
end

@testset "Run" begin
    @test Run(comment = "a") == Run(Dict{Symbol, String}(), "a")
end

@testset "push!" begin

    push!(A, P1)
    push!(A, P2)
    push!(A, P1)

    @test length(A.pois) == 2
    @test last(A.pois) == P2

    push!(A, R1)
    push!(A, R2)
    push!(A, R3)
    push!(A, R3)

    @test length(A.runs) == 4
    @test last(A.runs) == Repetition(R3, 3)

    push!(A, (P1, Repetition(R1, 1)))
    push!(A, (P1, Repetition(R1, 1)))
    push!(A, (P2, Repetition(R2, 1)))
    push!(A, (P2, Repetition(R3, 2)))

    @test length(A.associations) == 3

    fake_run1 = Run(Dict(:a => "a", :b => "a"), "a comment")
    fake_run2 = Run(Dict(:a => "a", :b => "a", :z => "kaka"), "a comment")
    fake_run3 = Run(Dict(:a => "a", :b => "a", :c => "b", :z => "kaka"), "a comment")

    @test_throws AssertionError push!(A, fake_run1)
    @test_throws AssertionError push!(A, fake_run2)
    @test_throws AssertionError push!(A, fake_run3)

end

@testset "replace!" begin

    replace!(A, P1, P3)

    @test !(P1 in A) && P3 in A
    @test !(P1 in map(first, A.associations)) && P3 in map(first, A.associations)

    replace!(A, Repetition(R3, 2), R1)

    B = Association()
    push!(B, P1)
    push!(B, P2)
    push!(B, P1)
    push!(B, R1)
    push!(B, R2)
    push!(B, R1)
    push!(B, R3)
    push!(B, (P1, Repetition(R1, 1)))
    push!(B, (P1, Repetition(R1, 1)))
    push!(B, (P2, Repetition(R2, 1)))
    push!(B, (P2, Repetition(R1, 2)))

    @test A.runs == B.runs

end

@testset "delete!" begin

    delete!(A, P3)

    @test A.pois == OrderedSet{POI}([P2])
    @test !(P3 in map(first, A.associations))

    delete!(A, Repetition(R3, 2))

    @test !(Repetition(R3, 2) in A) && length(A.runs) == 3
    @test !(Repetition(R3, 2) in map(last, A.associations))

    B = deepcopy(A)
    delete!(A, Repetition(R3, 2))

    @test A == B

    k = (P2, Repetition(R2, 1))

    @test k in A

    delete!(A, k)

    @test !(k in A)

    delete!(A, A.runs[1])
    @test A.runs[2].repetition == 1
end

@testset "Load & save" begin

    save(folder, target_vfs)
    vfs = loadLogVideoFiles(folder)

    @test length(vfs) == 2
    @test all(vfs[vf.file] == vf.datetime for vf in target_vfs)

    save(folder, A)

    @test A == loadAssociation(folder)

    runs["zzz"] = ["first", "asdasdasd"]
    open(joinpath(folder, "metadata", "run.csv"), "w") do o
        for (k, v) in runs
            join(o, [k, v...], ",")
            print(o, '\n')
        end
    end

    for r in A.runs
        r.run.metadata[:zzz] = "first"
    end

    @test A == loadAssociation(folder)

end

@testset "Time" begin

    t1 = 2
    Δ = 4
    P1 = POI("name1", Point("a.mp4", Second(t1)), Point("a.mp4", Second(t1 + Δ)), "label", "comment")
    @test Associations.duration(P1, "bogus") == Δ

    t1 = 0
    t2 = 1
    P1 = POI("name1", Point("a.mp4", Second(t1)), Point("b.mp4", Second(t2)), "label", "comment")
    @test Associations.duration(P1, videofolder) == 2

    P1 = POI("name1", Point("a.mp4", Second(0)), Point("a.mp4", Second(0)), "label", "comment")
    @test Associations.timeofday(P1, videofolder) == Dates.Time(16, 04, 47)
    P2 = POI("name1", Point("b.mp4", Second(0)), Point("a.mp4", Second(0)), "label", "comment")
    @test Associations.timeofday(P2, videofolder) == Dates.Time(15, 38, 25)

end

@testset "Other" begin

    @test empty!(A) == Association()
    @test isempty(A)

end

