__precompile__()
module Associations

# assuming right now that all durations and times are positive

import Base: push!, ==, empty!

export VideoFile, Point, POI, Run, Association, getVideoFiles, push!, save, shorten, openit, ==, empty!, loadAssociation

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

immutable VideoFile
    file::String
    datetime::Vector{DateTime}
    duration::Dates.Second
end

==(a::VideoFile, b::VideoFile) = a.file == b.file && a.datetime == b.datetime && a.duration == b.duration

function VideoFile(folder::String, file::String)
    fullfile = joinpath(folder, file)
    @assert isfile(fullfile)
    duration_, dateTimeOriginal, createDate, modifyDate = strip.(split(readstring(`exiftool -T -duration -AllDates -n $fullfile`), '\t'))
    #duration_, dateTimeOriginal, createDate, modifyDate  = ("-", "-", "-", "-")
    duration = Dates.Second(duration_ == "-" ? typemax(Int) : ceil(Int, parse(duration_)))
    datetime = DateTime(now())
    for i in [dateTimeOriginal, createDate, modifyDate]
        m = matchall(r"^(\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d)", i)
        isempty(m) && continue
        datetime = min(datetime, DateTime(m[1], "yyyy:mm:dd HH:MM:SS"))
    end
    VideoFile(file, [datetime], duration)
end


immutable Point
    file::VideoFile
    time::Dates.Second
    function Point(f, t)
        @assert t <= f.duration
        new(f, t)
    end
end

==(a::Point, b::Point) = a.file == b.file && a.time == b.time

immutable POI
    name::String
    start::Point
    stop::Point
    comment::String
    function POI(n, start, stop, c)
        if start.file == stop.file
            @assert start.time <= stop.time
        end
        new(n, start, stop, c)
    end
end


function POI()
    f = VideoFile("", [DateTime()], Dates.Second(0))
    p = Point(f, Dates.Second(0))
    return POI("", p, p, "")
end

==(a::POI, b::POI) = a.name == b.name && a.comment == b.comment && a.start == b.start && a.stop == b.stop


immutable Run
    metadata::Dict{Symbol, String}
    repetition::Int
end

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

function save(folder::String, x::Vector{VideoFile})
    n = length(x)
    a = Matrix{Any}(n + 1,3)
    a[1,:] .= ["file", "date and time", "video duration (sec)"]
    for (i, v) in enumerate(x)
        a[i + 1, :] .= [v.file, v.datetime[1], v.duration.value]
    end
    writecsv(joinpath(folder, "files.csv"), a)
end

function save(folder::String, x::Vector{POI}) 
    n = length(x)
    a = Matrix{Any}(n + 1,6)
    a[1,:] .= ["name", "start file", "start time (seconds)", "stop file", "stop time (seconds)", "comments"]
    for (i, t) in enumerate(x)
        a[i + 1, :] .= [t.name, t.start.file.file, t.start.time.value, t.stop.file.file, t.stop.time.value, t.comment]
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

type Association
    pois::Vector{POI}
    npois::Int
    runs::Vector{Run}
    nruns::Int
    associations::Set{Tuple{Int, Int}}
    Association(t, r, a) = new(t, length(t), r, length(r), a)
end

Association() = Association(POI[], Run[], Set())

function push!(a::Association, t::POI)
    a.npois += 1
    push!(a.pois, t)
end

function push!(a::Association, metadata::Dict{Symbol, String})
    a.nruns += 1
    push!(a.runs, metadata)
end

function empty!(a::Association)
    empty!(a.pois)
    empty!(a.runs)
    a.npois = 0
    a.nruns = 0
end

function save(folder::String, a::Association)
    folder = joinpath(folder, "log")
    isdir(folder) || mkdir(folder)
    if a.npois > 0
        b = Set{VideoFile}()
        for t in a.pois, vf in [t.start.file, t.stop.file]
            push!(b, vf)
        end
        vfs = collect(keys(b.dict))
        save(folder, vfs)
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


function loadVideoFiles(folder::String)::Vector{VideoFile}
    filescsv = joinpath(folder, "files.csv")
    vfs = VideoFile[]
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        @assert ncol == 3
        for i = 1:nrow
            push!(vfs, VideoFile(a[i, 1], [DateTime(a[i, 2])], Dates.Second(parse(Int, a[i, 3]))))
        end
    end
    return vfs
end

function getVideoFiles(folder::String)
    #old = uploadsavedVideoFiles(folder)
    new = VideoFile[]
    for (root, dir, files) in walkdir(folder)
        for file in files
            file[1] == '.' && continue
            last(splitext(file)) in exts || continue
            fname = relpath(joinpath(root, file), folder)
            #any(f.file == fname for f in old) && continue
            push!(new, VideoFile(folder, fname))
        end
    end
    return new
    #return (old, new)
end

function loadPOIs(folder::String, vfs = loadVideoFiles(folder))::Vector{POI}
    filescsv = joinpath(folder, "pois.csv")
    tgs = POI[]
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        @assert ncol == 6
        for i = 1:nrow
            fstart = vfs[findfirst(x -> x.file == a[i, 2], vfs)]
            fstop = vfs[findfirst(x -> x.file == a[i, 4], vfs)]
            push!(tgs, POI(a[i, 1], Point(fstart, Dates.Second(parse(Int, a[i, 3]))), Point(fstop, Dates.Second(parse(Int, a[i, 5]))), a[i, 6]))
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


include(joinpath(Pkg.dir("Associations"), "src", "utility.jl"))

end # module
