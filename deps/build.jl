using BinDeps

#=@BinDeps.setup

exiftool = library_dependency("exiftool", aliases=["exiftool.exe"])

if is_windows() # doesn't seem to work on Jochen's laptop. But works when done manually
    provides(Sources, URI("http://www.sno.phy.queensu.ca/~phil/exiftool/exiftool-10.48.zip"), exiftool, os = :Windows)
end

if is_unix()
    provides(Sources, URI("http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-10.48.tar.gz"), exiftool)
end

provides(BuildProcess, Autotools(libtarget = "exiftool"), exiftool)

try # this works but produvces an error
    @BinDeps.install Dict(:exiftool => :exiftool)
end=#

basedir = dirname(@__FILE__)

program = "exiftool"

if is_unix()
    file = "Image-ExifTool-10.49"
    extension = ".tar.gz"
    binary_name = target = program
end

if is_windows()
    file = "exiftool-10.49"
    extension = ".zip"
    binary_name = "$program.exe"
    target = "exiftool(-k).exe"
end

filename = file*extension
url = "http://www.sno.phy.queensu.ca/~phil/exiftool/$filename"

#run(@build_steps begin
    #FileRule(joinpath(basedir, "bin", binary_name)),
    run(@build_steps begin
     FileDownloader(url, joinpath(basedir, "downloads", filename))
     CreateDirectory(joinpath(basedir, "src"))
     FileUnpacker(joinpath(basedir, "downloads", filename), joinpath(basedir, "src"), "")
     #=f = first(sort(filter(r"exiftool", readdir(joinpath(basedir, "src", file))), by = length))
     cp(joinpath(basedir, "src", file, f), joinpath(basedir, "bin", binary_name))=#
     end)
    #end)

#target = first(sort(filter(r"exiftool", readdir(joinpath(basedir, "src", file))), by = length))
mv(joinpath(basedir, "src", file), joinpath(basedir, "src", "exiftool"), remove_destination = true)
if is_windows()
    mv(joinpath(basedir, "src", "exiftool", target), joinpath(basedir, "src", "exiftool", binary_name))
    symlink(joinpath(basedir, "src", "exiftool",binary_name), joinpath(basedir, "src", "exiftool", program))
end





    #=basedir = joinpath(Pkg.dir("Associations"), "deps")
    downloadsdir = joinpath(basedir, "downloads")
    srcdir = joinpath(basedir, "src")

    run(@build_steps begin
        CreateDirectory(downloadsdir)
        FileDownloader(url, joinpath(downloadsdir, filename))
        CreateDirectory(joinpath(basedir, "src"))
        FileUnpacker(downloads,
        joinpath(basedir, "src"),
        "")
    end)=#
