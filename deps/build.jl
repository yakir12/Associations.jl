using BinDeps

@BinDeps.setup

mediainfo = library_dependency("mediainfo", aliases = ["mediainfo.exe"])

# package managers
provides(AptGet, "mediainfo", mediainfo)
provides(Yum, "mediainfo", mediainfo)
provides(Pacman, "mediainfo", mediainfo)

provides(Binaries, URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Mac.dmg"), mediainfo, os=:Mac)
#if is_apple() 
#end

provides(Binaries, URI("https://mediaarea.net/download/binary/mediainfo/0.7.94/MediaInfo_CLI_0.7.94_Windows_x64.zip"), mediainfo, os=:Windows)
#if is_windows() 
#end

provides(BuildProcess, Autotools(libtarget = "mediainfo"), mediainfo)

@BinDeps.install #Dict(:mediainfo => :mediainfo)
