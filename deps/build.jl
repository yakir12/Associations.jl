using BinDeps

@BinDeps.setup

mediainfo = library_dependency("mediainfo", aliases = ["mediainfo.exe"])

# package managers
provides(AptGet, "mediainfo", mediainfo)
provides(Yum, "mediainfo", mediainfo)
provides(Pacman, "mediainfo", mediainfo)

if is_apple()
    provides(Binaries, 
             URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Mac.dmg"), 
             mediainfo, os=:Mac)
end

# Windows
if is_windows()
    provides(Binaries,#Sources
         #URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Windows_x64.zip"),
         URI("https://mediaarea.net/download/binary/libmediainfo0/0.7.94/MediaInfo_DLL_0.7.94_Windows_x64_WithoutInstaller.7z"),
         mediainfo, os = :Windows)
end

@BinDeps.install Dict(:mediainfo => :mediainfo)
