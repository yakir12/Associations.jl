using Associations
using Base.Test

folder = joinpath(Pkg.dir("Associations"), "test", "data")
files = Associations.getVideoFiles(folder)
vf = [Associations.VideoFile(folder, file) for file in files]
# write your own tests here
@test length(vf) == 1
@test vf[1] == Associations.VideoFile("a.MTS",[DateTime("2016-11-11T22:32:14")])
