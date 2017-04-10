using BinDeps

@BinDeps.setup

exiftool = library_dependency("exiftool", aliases=["exiftool.exe"])

provides(Sources, URI("http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-10.48.tar.gz"), exiftool, unpacked_dir = "downloads")
provides(BuildProcess, Autotools(libtarget = "exiftool.la"), exiftool)

try
    @BinDeps.install Dict(:exiftool => :exiftool)
end

