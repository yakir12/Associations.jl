__precompile__()
module Associations

using Gtk.ShortNames, GtkReactive

import Base: push!, ==, empty!

#export VideoFile, Point, POI, Run, Association, getVideoFiles, push!, save, shorten, openit, ==, empty!, loadAssociation, loadVideoFiles
export poirun, checkvideos

path = joinpath("..", "deps", "src")
folders = readdir(path)
exiftool = joinpath(path, last(folders), "exiftool")

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

immutable VideoFile
    file::String
    datetime::Vector{DateTime}
end

==(a::VideoFile, b::VideoFile) = a.file == b.file && a.datetime == b.datetime

function VideoFile(folder::String, file::String)
    fullfile = joinpath(folder, file)
    dateTimeOriginal, createDate, modifyDate = strip.(split(readstring(`$exiftool -T -AllDates -n $fullfile`), '\t'))
    #duration_, dateTimeOriginal, createDate, modifyDate  = ("-", "-", "-", "-")
    datetime = DateTime(now())
    for i in [dateTimeOriginal, createDate, modifyDate]
        m = matchall(r"^(\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d)", i)
        isempty(m) && continue
        datetime = min(datetime, DateTime(m[1], "yyyy:mm:dd HH:MM:SS"))
    end
    VideoFile(file, [datetime])
end

function getVideoFiles(folder::String)
    #old = uploadsavedVideoFiles(folder)
    new = String[]
    for (root, dir, files) in walkdir(folder)
        for file in files
            file[1] == '.' && continue
            last(splitext(file)) in exts || continue
            fname = relpath(joinpath(root, file), folder)
            push!(new, fname)
        end
    end
    return new
end

immutable Point
    file::String
    time::Dates.Second
end

Point(f::String, h::Int, m::Int, s::Int) = Point(f, sum(Dates.Second.([Dates.Hour(h), Dates.Minute(m), Dates.Second(s)])))

==(a::Point, b::Point) = a.file == b.file && a.time == b.time

immutable POI
    name::String
    start::Point
    stop::Point
    comment::String
end

function POI()
    p = Point("", Dates.Second(0))
    return POI("", p, p, "")
end

==(a::POI, b::POI) = a.name == b.name && a.comment == b.comment && a.start == b.start && a.stop == b.stop

immutable Run
    metadata::Dict{Symbol, String}
    repetition::Int
end

type Association
    pois::Vector{POI}
    npois::Int
    runs::Vector{Run}
    nruns::Int
    associations::Set{Tuple{Int, Int}}
    Association(t, r, a) = new(t, length(t), r, length(r), a)
end

Association() = Association(POI[], Run[], Set())



# pushes

function push!(xs::Vector{Run}, metadata::Dict{Symbol, String})
    repetition = 0
    for x in xs
        # when counting the number of repetitions, ignore any discrepancy between the comments
        same = true
        for k in keys(metadata)
            r"comment"i(string(k)) && continue
            if metadata[k] != x.metadata[k]
                same = false
                break
            end
        end
        same || continue
        repetition = max(repetition, x.repetition)
    end
    r = Run(metadata, repetition + 1)
    push!(xs, r)
end

function push!(a::Association, t::POI)
    push!(a.pois, t)
    #a.npois = length(a.pois)
    a.npois += 1
    return a
end

function push!(a::Association, metadata::Dict{Symbol, String})
    push!(a.runs, metadata)
    #a.nruns = length(a.runs)
    a.nruns += 1
    return a
end

# saves

function save(folder::String, x::Vector{VideoFile})
    n = length(x)
    a = Matrix{Any}(n + 1,2)
    a[1,:] .= ["file", "date and time"]
    for (i, v) in enumerate(x)
        a[i + 1, :] .= [v.file, v.datetime[1]]
    end
    writecsv(joinpath(folder, "log", "files.csv"), a)
end

function save(folder::String, x::Vector{POI}) 
    n = length(x)
    a = Matrix{Any}(n + 1,6)
    a[1,:] .= ["name", "start file", "start time (seconds)", "stop file", "stop time (seconds)", "comments"]
    for (i, t) in enumerate(x)
        a[i + 1, :] .= [t.name, t.start.file, t.start.time.value, t.stop.file, t.stop.time.value, t.comment]
    end
    writecsv(joinpath(folder, "pois.csv"), a)
end

function save(folder::String, x::Vector{Run})
    ks = collect(keys(x[1].metadata))
    header = string.(ks)
    push!(header, "repetition")
    n = length(x)
    a = Matrix{Any}(n + 1, length(ks) + 1)
    a[1,:] .= header
    for (i, r) in enumerate(x)
        for (j, k) in enumerate(ks)
            a[i + 1, j] = r.metadata[k]
        end
        a[i + 1, end] = r.repetition
    end
    writecsv(joinpath(folder, "runs.csv"), a)
end

function save(folder::String, a::Association)
    folder = joinpath(folder, "log")
    isdir(folder) || mkdir(folder)
    if a.npois > 0
        save(folder, a.pois)
    end
    if a.nruns > 0
        save(folder, a.runs)
    end
    if !isempty(a.associations)
        open(joinpath(folder, "associations.csv"), "w") do o
            println(o, "POI number, run number")
            for (t, r) in a.associations
                println(o, t, ",", r)
            end
        end
    end
end

# loads

function loadVideoFiles(folder::String)::Vector{VideoFile}
    filescsv = joinpath(folder, "log", "files.csv")
    vfs = VideoFile[]
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            push!(vfs, VideoFile(a[i, 1], [DateTime(a[i, 2])]))
        end
    end
    return vfs
end

function loadPOIs(folder::String)::Vector{POI}
    filescsv = joinpath(folder, "pois.csv")
    tgs = POI[]
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            push!(tgs, POI(a[i, 1], Point(a[i, 2], Dates.Second(parse(Int, a[i, 3]))), Point(a[i, 4], Dates.Second(parse(Int, a[i, 5]))), a[i, 6]))
        end
    end
    return tgs
end

function loadRuns(folder::String)::Vector{Run}
    filescsv = joinpath(folder, "runs.csv")
    rs = Run[]
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, String, header = true)
        ks = Symbol.(strip.(ks))
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            metadata = Dict{Symbol, String}()
            for j = 1:ncol - 1
                metadata[ks[j]] = a[i, j]
            end
            repetition = parse(Int, a[i, ncol])
            push!(rs, Run(metadata, repetition))
        end
    end
    return rs
end

function loadAssociation(folder::String)::Association
    folder = joinpath(folder, "log")
    ts = loadPOIs(folder)
    rs = loadRuns(folder)
    filescsv = joinpath(folder, "associations.csv")
    as = Set{Tuple{Int, Int}}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, Int, header = true)
        nrow, ncol = size(a)
        @assert ncol == 2
        for i = 1:nrow
            push!(as, (a[i,1], a[i,2]))
        end
    end
    return Association(ts, rs, as)
end

# empty

function empty!(a::Association)
    empty!(a.pois)
    empty!(a.runs)
    a.npois = 0
    a.nruns = 0
end

include(joinpath(Pkg.dir("Associations"), "src", "util.jl"))

include(joinpath(Pkg.dir("Associations"), "src", "gui.jl"))

end # module
