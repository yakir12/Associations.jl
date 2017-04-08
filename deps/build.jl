using BinDeps
using Compat

@BinDeps.setup

mediainfo = library_dependency("mediainfo")

# package managers
provides(AptGet, "mediainfo", mediainfo)
provides(Yum, "mediainfo", mediainfo)
provides(Pacman, "mediainfo", mediainfo)

if is_apple() 
    provides(Sources, URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Mac.dmg"), mediainfo)
    provides(BuildProcess, Autotools(libtarget = "mediainfo"), mediainfo)
end

if is_windows() 
    provides(Sources, URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Windows_x64.zip"), mediainfo)
    provides(BuildProcess, Autotools(libtarget = "mediainfo"), mediainfo)
end

@BinDeps.install Dict(:mediainfo => :mediainfo)
