using BinDeps

@BinDeps.setup

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
end

