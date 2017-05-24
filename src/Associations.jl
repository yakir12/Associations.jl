__precompile__()
module Associations

using DataStructures, AutoHashEquals

import Base: push!, empty!, delete!, isempty

export VideoFile, Point, POI, Run, Repetition, Association, getVideoFiles, loadAssociation, loadVideoFiles, push!, empty!, delete!, isempty

exiftool = joinpath(Pkg.dir("Associations"), "deps", "src", "exiftool", "exiftool")
if is_windows()
    exiftool *= ".exe"
end

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

@auto_hash_equals immutable VideoFile
    file::String
    datetime::DateTime
end

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

@auto_hash_equals immutable Run
    metadata::Dict{Symbol, String}
    comment::String
    visible::Bool
end

Run(metadata, comment) = Run(metadata, comment, true)
Run(;metadata = Dict(:nothing => "nothing"), comment = "") = Run(metadata, comment)

@auto_hash_equals immutable Repetition
    run::Run
    repetition::Int
end

@auto_hash_equals immutable Association
    pois::OrderedSet{POI}
    runs::OrderedSet{Repetition}
    associations::Set{Tuple{POI, Repetition}}
end

Association() = Association(OrderedSet{POI}(), OrderedSet{Repetition}(), Set{Tuple{POI, Repetition}}())

# pushes

function push!(xs::OrderedSet{Repetition}, r::Run)
    repetition = reduce((x, y) -> max(x, y.run.metadata == r.metadata ? y.repetition : 0), 0, xs) + 1
    push!(xs, Repetition(r, repetition))
end

function push!(a::Association, t::POI)
    push!(a.pois, t)
    return a
end

function push!(a::Association, r::Run)
    push!(a.runs, r)
    return a
end

# deletes

function delete!(a::Association, r::Repetition)
    delete!(a.runs, r)
    filter!(x -> last(x) != r, a.associations)
    new = OrderedSet{Repetition}()
    for x in a.runs
        if x.run.metadata == r.run.metadata && x.repetition > r.repetition
            n = Repetition(x.run, x.repetition - 1)
            push!(new, n)
            for ai in a.associations
                if last(ai) == x
                    push!(a.associations, (first(ai), n))
                    delete!(a.associations, ai)
                end
            end
        else
            push!(new, x)
        end
    end
    empty!(a.runs)
    push!(a.runs, new...)
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

function save(folder::String, x::OrderedSet{Repetition})
    ks = sort(collect(keys(x[1].run.metadata)))
    header = string.(ks)
    push!(header, "repetition")
    n = length(x)
    a = Matrix{String}(n + 1, length(ks) + 1)
    a[1,:] .= header
    for (i, r) in enumerate(x)
        for (j, k) in enumerate(ks)
            a[i + 1, j] = r.run.metadata[k]
        end
        a[i + 1, end] = r.run.comment
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

# edit comment

function edit_comment!(a::Association, x::Repetition, c::String)
    x.run.comment == c && return a
    new = OrderedSet{Repetition}()
    for xi in a.runs
        if xi == x
            n = Repetition(Run(x.run.metadata, c), x.repetition)
            push!(new, n)
            for ai in a.associations
                if last(ai) == x
                    push!(a.associations, (first(ai), n))
                    delete!(a.associations, ai)
                end
            end
        else
            push!(new, xi)
        end
    end
    empty!(a.runs)
    push!(a.runs, new...)
    return a
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

function loadRuns(folder::String)::OrderedSet{Repetition}
    filescsv = joinpath(folder, "runs.csv")
    rs = OrderedSet{Repetition}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, String, header = true, quotes = true)
        ks = Symbol.(strip.(ks))
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            metadata = Dict{Symbol, String}()
            for j = 1:ncol - 2
                metadata[ks[j]] = a[i, j]
            end
            comment = a[i, ncol - 1]
            repetition = parse(Int, a[i, ncol])
            push!(rs, Repetition(Run(metadata, comment), repetition))
        end
    end
    return rs
end

function loadAssociation(folder::String)::Association
    folder = joinpath(folder, "log")
    ts = loadPOIs(folder)
    rs = loadRuns(folder)
    filescsv = joinpath(folder, "associations.csv")
    as = Set{Tuple{POI, Repetition}}()
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

end # module
