__precompile__()
module Associations

using DataStructures, AutoHashEquals, Base.Dates

import Base: push!, empty!, delete!, isempty

export VideoFile, Point, POI, Run, Repetition, Association, getVideoFiles, loadVideoFiles, loadPOIs, loadRuns, loadAssociation, save, push!, empty!, delete!, isempty, replace!

exiftool_base = joinpath(Pkg.dir("Associations"), "deps", "src", "exiftool", "exiftool")
const exiftool = exiftool_base*(is_windows() ? ".exe" : "")

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
    time::Second
end

Point(;file = "", time = Second(0)) = Point(file, time)
Point(f::String, h::Int, m::Int, s::Int) = Point(f, sum(Second.([Hour(h), Minute(m), Second(s)])))

@auto_hash_equals immutable POI
    name::String
    start::Point
    stop::Point
    label::String
    comment::String
    visible::Bool
end

POI(name, start, stop, label, comment) = POI(name, start, stop, label, comment, true)

POI(;name = "", start = Point(), stop = Point(), label = "", comment = "") = POI(name, start, stop, label, comment)

@auto_hash_equals immutable Run
    metadata::Dict{Symbol, String}
    comment::String
    visible::Bool
end

Run(metadata, comment) = Run(metadata, comment, true)
Run(;metadata = Dict{Symbol, String}(), comment = "") = Run(metadata, comment)

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

run2repetition(xs::OrderedSet{Repetition}, r::Run) = Repetition(r, reduce((x, y) -> max(x, y.run.metadata == r.metadata ? y.repetition : 0), 0, xs) + 1)

push!(xs::OrderedSet{Repetition}, r::Run) = push!(xs, run2repetition(xs, r))

function push!(a::Association, t::POI)
    push!(a.pois, t)
    return a
end

function push!(a::Association, r::Run)
    push!(a.runs, r)
    return a
end

function push!(a::Association, x::Tuple{POI, Repetition})
    @assert first(x) in a.pois
    @assert last(x) in a.runs
    push!(a.associations, x)
end


# replace

replace!(xs::OrderedSet{Repetition}, o::Repetition, n::Repetition) = OrderedSet{Repetition}(x == o ? n : x for x in xs)
replace!(xs::Set{Tuple{POI, Repetition}}, o::Repetition, n::Repetition) = Set{Tuple{POI, Repetition}}(last(x) == o ? (first(x), n) : x for x in xs)
function replace!(a::Association, o::Repetition, n::Repetition)
    o == n && return a
    runs = replace!(a.runs, o, n)
    empty!(a.runs)
    push!(a.runs, runs...)
    isempty(a.associations) && return a 
    associations = replace!(a.associations, o, n)
    empty!(a.associations)
    push!(a.associations, associations...)
    return a
end
replace!(a::Association, o::Repetition, n::Run) = replace!(a, o, run2repetition(setdiff(a.runs, OrderedSet([o])), n))

replace!(xs::OrderedSet{POI}, o::POI, n::POI) = OrderedSet{POI}(x == o ? n : x for x in xs)
replace!(xs::Set{Tuple{POI, Repetition}}, o::POI, n::POI) = Set{Tuple{POI, Repetition}}(first(x) == o ? (n, last(x)) : x for x in xs)
function replace!(a::Association, o::POI, n::POI)
    o == n && return a
    pois = replace!(a.pois, o, n)
    empty!(a.pois)
    push!(a.pois, pois...)
    isempty(a.associations) && return a 
    associations = replace!(a.associations, o, n)
    empty!(a.associations)
    push!(a.associations, associations...)
    return a
end

# deletes

function delete!(a::Association, r::Repetition)
    r in a.runs || return a
    delete!(a.runs, r)
    filter!(x -> last(x) != r, a.associations)
    for x in a.runs
        if x.run.metadata == r.run.metadata && x.repetition > r.repetition
            replace!(a, x, Repetition(x.run, x.repetition - 1))
        end
    end
    return a
end

function delete!(a::Association, p::POI)
    p in a.pois || return a
    delete!(a.pois, p)
    filter!(x -> first(x) != p, a.associations)
    return a
end

function delete!(a::Association, x::Tuple{POI, Repetition})
    x in a.associations || return a
    @assert first(x) in a.pois
    @assert last(x) in a.runs
    delete!(a.associations, x)
    return a
end

# saves

function prep_file(folder::String, what::String)::String
    folder = joinpath(folder, "log")
    isdir(folder) || mkdir(folder)
    return joinpath(folder, "$what.csv")
end

function save(folder::String, x::Set{VideoFile})
    file = prep_file(folder, "files")
    #isempty(x) && rm(file, force=true)
    n = length(x)
    a = Matrix{String}(n + 1,2)
    a[1,:] .= ["file", "date and time"]
    for (i, v) in enumerate(x)
        a[i + 1, :] .= [v.file, string(v.datetime)]
    end
    writecsv(file, a)
end

function save(folder::String, x::OrderedSet{POI}) 
    file = prep_file(folder, "pois")
    n = length(x)
    a = Matrix{String}(n + 1,7)
    a[1,:] .= ["name", "start file", "start time (seconds)", "stop file", "stop time (seconds)", "label", "comments"]
    for (i, t) in enumerate(x)
        a[i + 1, :] .= [t.name, t.start.file, string(t.start.time.value), t.stop.file, string(t.stop.time.value), t.label, t.comment]
    end
    a .= strip.(a)
    writecsv(file, a)
end

function save(folder::String, x::OrderedSet{Repetition})
    file = prep_file(folder, "runs")
    ks = sort(collect(keys(x[1].run.metadata)))
    header = string.(ks)
    push!(header, "comment", "repetition")
    n = length(x)
    a = Matrix{String}(n + 1, length(header))
    a[1,:] .= header
    for (i, r) in enumerate(x)
        for (j, k) in enumerate(ks)
            a[i + 1, j] = r.run.metadata[k]
        end
        a[i + 1, end - 1] = r.run.comment
        a[i + 1, end] = string(r.repetition)
    end
    a .= strip.(a)
    writecsv(file, a)
end

function save(folder::String, a::Association)
    save(folder, a.pois)
    save(folder, a.runs)
    file = prep_file(folder, "associations")
    open(file, "w") do o
        println(o, "POI number, run number")
        for (t, r) in a.associations
            ti = findfirst(a.pois, t)
            ri = findfirst(a.runs, r)
            println(o, ti, ",", ri)
        end
    end
end
# edit comment

#=function edit_comment!(a::Association, x::Repetition, c::String)
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
end=#


# loads

function loadVideoFiles(folder::String)::Set{VideoFile}
    filescsv = joinpath(folder, "log", "files.csv")
    vfs = Set{VideoFile}()
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true, quotes = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        for i = 1:nrow
            vf = VideoFile(a[i, 1], DateTime(a[i, 2]))
            @assert !(vf in vfs)
            push!(vfs, vf)
        end
    end
    return vfs
end

function loadPOIs(folder::String)::OrderedSet{POI}
    filescsv = joinpath(folder, "log", "pois.csv")
    tgs = OrderedSet{POI}()
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true, quotes = true)
        a .= strip.(a)
        nrow, ncol = size(a)
        @assert ncol == 7
        for i = 1:nrow
            tg = POI(a[i, 1], Point(a[i, 2], Second(parse(Int, a[i, 3]))), Point(a[i, 4], Second(parse(Int, a[i, 5]))), a[i, 6], a[i, 7])
            @assert !(tg in tgs)
            push!(tgs, tg)
        end
    end
    return tgs
end

function loadRuns(folder::String)::OrderedSet{Repetition}
    filescsv = joinpath(folder, "log", "runs.csv")
    rs = OrderedSet{Repetition}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, String, header = true, quotes = true)
        ks = Symbol.(strip.(ks))
        a .= strip.(a)
        nks = length(ks)
        nrow, ncol = size(a)
        @assert nks == ncol > 2
        for i = 1:nrow
            metadata = Dict{Symbol, String}()
            for j = 1:ncol - 2
                metadata[ks[j]] = a[i, j]
            end
            comment = a[i, ncol - 1]
            repetition = parse(Int, a[i, ncol])
            r = Repetition(Run(metadata, comment), repetition)
            @assert !(r in rs)
            push!(rs, r)
        end
    end
    return rs
end

function loadAssociation(folder::String)::Association
    ts = loadPOIs(folder)
    rs = loadRuns(folder)
    filescsv = joinpath(folder, "log", "associations.csv")
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
    return a
end

isempty(a::Association) = isempty(a.pois) && isempty(a.runs) && isempty(a.associations)

end # module
