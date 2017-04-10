using Associations
using Base.Test

folder = joinpath(Pkg.dir("Associations"), "test", "videofolder")
files = Associations.getVideoFiles(folder)
vf = [Associations.VideoFile(folder, file) for file in files]
a = [Associations.VideoFile("a.mp4",[DateTime("2017-02-28T16:04:47")]), Associations.VideoFile("b.mp4",[DateTime("2017-03-02T15:38:25")])]
files = ["a.mp4", "b.mp4"]
# write your own tests here
@test length(vf) == 2
for file in files
    ai = filter(x -> x.file == file, a)
    v = filter(x -> x.file == file, vf)
    @test ai == v
end
