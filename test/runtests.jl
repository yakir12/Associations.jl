using Associations
using Base.Test

folder = joinpath(Pkg.dir("Associations"), "test", "data")
files = Associations.getVideoFiles(folder)
vf = [Associations.VideoFile(folder, file) for file in files]
# write your own tests here
@test length(vf) == 1
@test vf[1] == Associations.VideoFile("a.mp4",[DateTime("2017-02-28T16:04:47")])
