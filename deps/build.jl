using BinDeps

@BinDeps.setup

exiftool = library_dependency("exiftool", aliases = ["exiftool.exe"])

# package managers
if is_unix()
    provides(Sources, 
             URI("http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-10.48.tar.gz"), 
             exiftool, os=:Mac)
end

if is_apple()
    provides(Sources, 
             URI("http://www.sno.phy.queensu.ca/~phil/exiftool/ExifTool-10.48.dmg"), 
             exiftool, os=:Mac)
end

# Windows
if is_windows()
    provides(Binaries,
         URI("http://www.sno.phy.queensu.ca/~phil/exiftool/exiftool-10.48.zip"),
         exiftool, os = :Windows)
end

#@BinDeps.install Dict(:exiftool => :exiftool)
