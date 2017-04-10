using BinDeps

@BinDeps.setup

exiftool = library_dependency("exiftool", aliases=["exiftool.exe"])
if is_windows()
    provides(Sources, URI("http://www.sno.phy.queensu.ca/~phil/exiftool/exiftool-10.48.zip"), exiftool, os = :Windows, unpacked_dir = "downloads")
end

provides(Sources, URI("http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-10.48.tar.gz"), exiftool, unpacked_dir = "downloads")
provides(BuildProcess, Autotools(libtarget = "exiftool"), exiftool)

try
    @BinDeps.install Dict(:exiftool => :exiftool)
end

