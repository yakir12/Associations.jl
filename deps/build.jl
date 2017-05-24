using BinDeps

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

if is_unix()
    run(
        @build_steps begin
        FileDownloader(url, joinpath(basedir, "downloads", filename))
        CreateDirectory(joinpath(basedir, "src"))
        FileUnpacker(joinpath(basedir, "downloads", filename), joinpath(basedir, "src"), "")
        end
       )
    mv(joinpath(basedir, "src", file), joinpath(basedir, "src", "exiftool"), remove_destination = true)
end

if is_windows()
    run(
        @build_steps begin
        FileDownloader(url, joinpath(basedir, "downloads", filename))
        CreateDirectory(joinpath(basedir, "src"))
        FileUnpacker(joinpath(basedir, "downloads", filename), joinpath(basedir, "src"), target)
        CreateDirectory(joinpath(basedir, "src", "exiftool"))
        end
       )
    mv(joinpath(basedir, "src", target), joinpath("src", "exiftool", binary_name), remove_destination = true)
end
