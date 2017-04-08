using BinDeps

@BinDeps.setup

mediainfo = library_dependency("mediainfo")

# package managers
provides(AptGet, "mediainfo", mediainfo)
provides(Yum, "mediainfo", mediainfo)
provides(Pacman, "mediainfo", mediainfo)

    provides(Sources, URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Mac.dmg"), mediainfo)
#if is_apple() 
#end

    provides(Sources, URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Windows_x64.zip"), mediainfo)
#if is_windows() 
#end

provides(BuildProcess, Autotools(libtarget = "mediainfo"), mediainfo)

@BinDeps.install Dict(:mediainfo => :mediainfo)
