__precompile__()
module Associations

using Gtk.ShortNames, GtkReactive, DataStructures, AutoHashEquals

import Base: push!, empty!, delete!, isempty#, hash, ==

export main, push!, empty!, delete!#, hash, ==
#export VideoFile, Point, POI, Run, Association, getVideoFiles, push!, save, shorten, openit, ==, empty!, loadAssociation, loadVideoFiles, poirun, checkvideos

exiftool = joinpath(Pkg.dir("Associations"), "deps", "src", "exiftool", "exiftool")
if is_windows()
    exiftool *= ".exe"
end

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

@auto_hash_equals immutable VideoFile
    file::String
    datetime::DateTime
end

# ==(a::VideoFile, b::VideoFile) = a.file == b.file && a.datetime == b.datetime


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
    VideoFile(file, datetime)
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

@auto_hash_equals immutable Point
    file::String
    time::Dates.Second
end

Point(f::String, h::Int, m::Int, s::Int) = Point(f, sum(Dates.Second.([Dates.Hour(h), Dates.Minute(m), Dates.Second(s)])))

# ==(a::Point, b::Point) = a.file == b.file && a.time == b.time
#hash(a::Point, h::UInt) = hash(a.file, hash(a.time, h))

@auto_hash_equals immutable POI
    name::String
    start::Point
    stop::Point
    label::String
    comment::String
    visible::Bool
end

POI(name, start, stop, label, comment) = POI(name, start, stop, label, comment, true)

POI(;name = "", start = Point("", Dates.Second(0)), stop = Point("", Dates.Second(0)), label = "", comment = "") = POI(name, start, stop, label, comment)


# ==(a::POI, b::POI) = a.name == b.name && a.comment == b.comment && a.start == b.start && a.stop == b.stop && a.label == b.label
#hash(a::POI, h::UInt) = hash(a.name, hash(a.start, hash(a.stop, hash(a.label, hash(a.comment, h)))))

@auto_hash_equals immutable Run
    metadata::Dict{Symbol, String}
    repetition::Int
    visible::Bool
end

Run(metadata, repetition) = Run(metadata, repetition, true)
Run(;metadata = Dict(:nothing => "nothing"), repetition = 0) = Run(metadata, repetition)

# ==(a::Run, b::Run) = a.metadata == b.metadata && a.repetition == b.repetition
#hash(a::Run, h::UInt) = hash(a.metadata, hash(a.repetition, h))

@auto_hash_equals immutable Association
    pois::OrderedSet{POI}
    runs::OrderedSet{Run}
    associations::OrderedSet{Tuple{POI, Run}}
end

Association() = Association(OrderedSet{POI}(), OrderedSet{Run}(), OrderedSet{Tuple{POI, Run}}())

# ==(a::Association, b::Association) = a.associations == b.associations && a.pois == b.pois && a.runs == b.runs
#=function hash(a::Association, h::UInt)
    for p in a.pois
        h = hash(p, h)
    end
    for r in a.runs
        h = hash(r, h)
    end
    for a in a.associations
        h = hash(first(a), hash(last(a), h))
    end
    return h
end=#

# pushes

function push!(xs::OrderedSet{Run}, metadata::Dict{Symbol, String})
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
    r = Run(metadata, repetition + 1, true)
    push!(xs, r)
end

function push!(a::Association, t::POI)
    push!(a.pois, t)
    return a
end

function push!(a::Association, metadata::Dict{Symbol, String})
    push!(a.runs, metadata)
    return a
end

# deletes

#=function delete!(rs::Vector{Run}, r::Run)
    metadata = r.metadata
    repetition = r.repetition
    filter!(x -> x != r, rs)
    for x in rs
        # when counting the number of repetitions, ignore any discrepancy between the comments
        if x.repetition > repetition && all(r"comment"i(string(k)) ? true : metadata[k] == x.metadata[k] for k in keys(metadata))
            x.repetition -= 1
        end
    end
    return rs
end=#

function delete!(a::Association, r::Run)
    delete!(a.runs, r)
    filter!(x -> last(x) != r, a.associations)
    return a
end

function delete!(a::Association, r::POI)
    delete!(a.pois, r)
    filter!(x -> first(x) != r, a.associations)
    return a
end

# saves

function save(folder::String, x::Vector{VideoFile})
    if isempty(x)
        rm(joinpath(folder, "log", "files.csv"), force=true)
    else
        n = length(x)
        a = Matrix{String}(n + 1,2)
        a[1,:] .= ["file", "date and time"]
        for (i, v) in enumerate(x)
            a[i + 1, :] .= [v.file, string(v.datetime)]
        end
        writecsv(joinpath(folder, "log", "files.csv"), a, quotes = true)
    end
end

function save(folder::String, x::OrderedSet{POI}) 
    n = length(x)
    a = Matrix{String}(n + 1,7)
    a[1,:] .= ["name", "start file", "start time (seconds)", "stop file", "stop time (seconds)", "label", "comments"]
    for (i, t) in enumerate(x)
        a[i + 1, :] .= [t.name, t.start.file, string(t.start.time.value), t.stop.file, string(t.stop.time.value), t.label, t.comment]
    end
    a .= strip.(a)
    writecsv(joinpath(folder, "pois.csv"), a, quotes = true)
end

function save(folder::String, x::OrderedSet{Run})
    ks = sort(collect(keys(x[1].metadata)))
    header = string.(ks)
    push!(header, "repetition")
    n = length(x)
    a = Matrix{String}(n + 1, length(ks) + 1)
    a[1,:] .= header
    for (i, r) in enumerate(x)
        for (j, k) in enumerate(ks)
            a[i + 1, j] = r.metadata[k]
        end
        a[i + 1, end] = string(r.repetition)
    end
    a .= strip.(a)
    writecsv(joinpath(folder, "runs.csv"), a, quotes = true)
end

function save(folder::String, a::Association)
    folder = joinpath(folder, "log")
    isdir(folder) || mkdir(folder)
    isempty(a.pois) ? rm(joinpath(folder, "pois.csv"), force=true) : save(folder, a.pois)
    isempty(a.runs) ? rm(joinpath(folder, "runs.csv"), force=true) : save(folder, a.runs)
    if !isempty(a.associations)
        open(joinpath(folder, "associations.csv"), "w") do o
            println(o, "POI number, run number")
            for (t, r) in a.associations
                ti = findfirst(a.pois, t)
                ri = findfirst(a.runs, r)
                println(o, ti, ",", ri)
            end
        end
    else
        rm(joinpath(folder, "associations.csv"), force=true)
    end
end

# loads

function loadVideoFiles(folder::String)::Vector{VideoFile}
    filescsv = joinpath(folder, "log", "files.csv")
    vfs = VideoFile[]
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true, quotes = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            push!(vfs, VideoFile(a[i, 1], DateTime(a[i, 2])))
        end
    end
    return vfs
end

function loadPOIs(folder::String)::OrderedSet{POI}
    filescsv = joinpath(folder, "pois.csv")
    tgs = OrderedSet{POI}()
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true, quotes = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            push!(tgs, POI(a[i, 1], Point(a[i, 2], Dates.Second(parse(Int, a[i, 3]))), Point(a[i, 4], Dates.Second(parse(Int, a[i, 5]))), a[i, 6], a[i, 7]))
        end
    end
    return tgs
end

function loadRuns(folder::String)::OrderedSet{Run}
    filescsv = joinpath(folder, "runs.csv")
    rs = OrderedSet{Run}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, String, header = true, quotes = true)
        ks = Symbol.(strip.(ks))
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            metadata = Dict{Symbol, String}()
            for j = 1:ncol - 1
                metadata[ks[j]] = a[i, j]
            end
            repetition = parse(Int, a[i, ncol])
            push!(rs, Run(metadata, repetition, true))
        end
    end
    return rs
end

function loadAssociation(folder::String)::Association
    folder = joinpath(folder, "log")
    ts = loadPOIs(folder)
    rs = loadRuns(folder)
    filescsv = joinpath(folder, "associations.csv")
    as = OrderedSet{Tuple{POI, Run}}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, Int, header = true)
        nrow, ncol = size(a)
        @assert ncol == 2
        for i = 1:nrow
            push!(as, (ts[a[i,1]], rs[a[i, 2]]))
        end
    end
    return Association(ts, rs, as)
end

# empty

function empty!(a::Association)
    empty!(a.pois)
    empty!(a.runs)
    empty!(a.associations)
end

isempty(a::Association) = isempty(a.pois) && isempty(a.runs) && isempty(a.associations)


include(joinpath(Pkg.dir("Associations"), "src", "util.jl"))

include(joinpath(Pkg.dir("Associations"), "src", "gui.jl"))

end # module
