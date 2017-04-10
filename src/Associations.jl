__precompile__()
module Associations

using Gtk.ShortNames, GtkReactive

import Base: push!, ==, empty!

#export VideoFile, Point, POI, Run, Association, getVideoFiles, push!, save, shorten, openit, ==, empty!, loadAssociation, loadVideoFiles
export poirun, checkvideos

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

immutable VideoFile
    file::String
    datetime::Vector{DateTime}
end

==(a::VideoFile, b::VideoFile) = a.file == b.file && a.datetime == b.datetime

function VideoFile(folder::String, file::String)
    fullfile = joinpath(folder, file)
    dateTimeOriginal, createDate, modifyDate = strip.(split(readstring(`exiftool -T -AllDates -n $fullfile`), '\t'))
    #duration_, dateTimeOriginal, createDate, modifyDate  = ("-", "-", "-", "-")
    datetime = DateTime(now())
    for i in [dateTimeOriginal, createDate, modifyDate]
        m = matchall(r"^(\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d)", i)
        isempty(m) && continue
        datetime = min(datetime, DateTime(m[1], "yyyy:mm:dd HH:MM:SS"))
    end
    VideoFile(file, [datetime])
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


function shorten(s::String, k::Int)::String
    m = length(s)
    m > 2k || return s
    s[1:k]*"…"*s[end-k + 1:end]
end
function shorten(vfs::Vector{String})
    for k = 20:max(20, maximum(length.(vfs)))
        shortnames = Dict{String, String}()
        tooshort = false
        for vf in vfs
            key = shorten(vf, k)
            if haskey(shortnames, k)
                tooshort = true
                break
            end
            shortnames[key] = vf
        end
        tooshort || return shortnames
    end
end
function openit(f::String)
    if is_windows()
        run(`start $f`)
    elseif is_linux()
        run(`xdg-open $f`)
    elseif is_apple()
        run(`open $f`)
    else
        error("Couldn't open $f")
    end
end
function checkvideos(folder)
    as = loadAssociation(folder)

    a = Set{String}()
    for t in as.pois, vf in [t.start.file, t.stop.file]
        push!(a, vf)
    end

    old = loadVideoFiles(folder)

    ft = VideoFile[]
    for k in keys(a.dict)
        found = false
        for f in old
            if k == f.file
                push!(ft, f)
                found = true
                break
            end
        end
        found || push!(ft, VideoFile(folder, k))
    end

    done = Button("Done")
    g = Grid()
    g[0,0] = Label("File")
    g[1,0] = Label("Year")
    g[2,0] = Label("Month")
    g[3,0] = Label("Day")
    g[4,0] = Label("Hour")
    g[5,0] = Label("Minute")
    g[6,0] = Label("Second")
    const baddate = DateTime()
    for (i, vf) in enumerate(ft)
        name = vf.file
        datetime = vf.datetime[1]
        play = button(name)
        y = spinbutton(1:10000, value = Dates.Year(datetime).value)
        m = spinbutton(1:12, value = Dates.Month(datetime).value)
        d = spinbutton(1:31, value = Dates.Day(datetime).value)
        H = spinbutton(0:23, value = Dates.Hour(datetime).value)
        M = spinbutton(0:59, value = Dates.Minute(datetime).value)
        S = spinbutton(0:59, value = Dates.Second(datetime).value)
        setproperty!(y.widget, :width_request, 5)
        setproperty!(m.widget, :width_request, 5)
        setproperty!(d.widget, :width_request, 5)
        setproperty!(H.widget, :width_request, 5)
        setproperty!(M.widget, :width_request, 5)
        setproperty!(S.widget, :width_request, 5)
        dt = map(signal(y), signal(m), signal(d), signal(H), signal(M), signal(S)) do y², m², d², H², M², S²
            try
                DateTime(y², m², d², H², M², S²)
            catch
                baddate
            end
        end
        gd = map(dt) do t²
            setproperty!(done, :sensitive, t² != baddate)
        end
        tasksplay, resultsplay = async_map(nothing, play) do _
            openit(joinpath(folder, name))
        end
        g[0,i] = play.widget
        g[1,i] = y.widget
        g[2,i] = m.widget
        g[3,i] = d.widget
        g[4,i] = H.widget
        g[5,i] = M.widget
        g[6,i] = S.widget
        vfh = map(dt) do dt²
            vf.datetime[1] = dt²
        end
    end
    doneh = signal_connect(done, :clicked) do _
        save(folder, ft)
        destroy(win)
    end
    g[0:6, length(ft) + 1] = done
    win = Window(g, "LogBeetle: Check videos", 1, 1)
    showall(win)




    #=h = map(done, init = nothing) do _
        save(folder, ft)
        destroy(win)
        nothing
    end=#

    c = Condition()
    signal_connect(win, :destroy) do _
        notify(c)
    end
    wait(c)
end

##################################################

function poirun(folder)
    win = Window("LogBeetle")
    #folder = "/home/yakir/datasturgeon/projects/marie/projectmanagement/main/testvideos"
    #folder = open_dialog("Select Dataset Folder", win, action=Gtk.GtkFileChooserAction.SELECT_FOLDER)

    # POI

    files = shorten(getVideoFiles(folder))
    points = strip.(vec(readcsv(joinpath(folder, "metadata", "poi.csv"), String)))
    # widgets
    shortfiles = collect(keys(files))
    poi = dropdown(points)
    fstart = dropdown(shortfiles)
    fstop = dropdown(shortfiles)
    s1 = spinbutton(0:59, orientation = "v")
    m1 = spinbutton(0:59, orientation = "v")
    h1 = spinbutton(0:23, orientation = "v")
    s2 = spinbutton(0:59, orientation = "v")
    m2 = spinbutton(0:59, orientation = "v")
    h2 = spinbutton(0:23, orientation = "v")
    comment = textarea("")
    poiadd = button("Add")
    # layout
    setproperty!(s1.widget, :width_request, 5)
    setproperty!(m1.widget, :width_request, 5)
    setproperty!(h1.widget, :width_request, 5)
    setproperty!(s2.widget, :width_request, 5)
    setproperty!(m2.widget, :width_request, 5)
    setproperty!(h2.widget, :width_request, 5)
    poig = Grid()
    poig[0,0] = Label("POI")
    poig[0,1] = Label("Start")
    poig[2,0] = Label("H")
    poig[3,0] = Label("M")
    poig[4,0] = Label("S")
    poig[0,2] = Label("Stop")
    poig[5,0] = Label("Comment")
    poig[1,0] = poi.widget
    poig[1,1] = fstart.widget
    poig[2,1] = h1.widget
    poig[3,1] = m1.widget
    poig[4,1] = s1.widget
    poig[1,2] = fstop.widget
    poig[2,2] = h2.widget
    poig[3,2] = m2.widget
    poig[4,2] = s2.widget
    poig[5,1:2] = comment.widget
    poig[6,0:2] = widget(poiadd)
    # function 
    tasksstart, resultsstart = async_map(nothing, signal(fstart)) do f²
        openit(joinpath(folder, files[f²]))
        return nothing
    end
    tasksstop, resultsstop = async_map(nothing, signal(fstop)) do f²
        openit(joinpath(folder, files[f²]))
        return nothing
    end
    fstar = map(x -> files[x], fstart)
    fsto = map(x -> files[x], fstop)
    startPoint = map(Point, fstar, signal(h1), signal(m1), signal(s1))
    stopPoint = map(Point, fsto, signal(h2), signal(m2), signal(s2))
    tt = map(POI, signal(poi), startPoint, stopPoint, signal(comment))
    t = map(_ -> value(tt), poiadd, init = value(tt))
    goodtime = map(startPoint, stopPoint) do start, stop
        start.file == stop.file ? start.time <= stop.time : true
    end
    poisignal = filterwhen(goodtime, POI(), t)


    # run

    # data
    a = readcsv(joinpath(folder, "metadata", "run.csv"))
    metadata = Dict{String, Vector{String}}()
    for i = 1:size(a,1)
        b = strip.(a[i,:])
        metadata[b[1]] = filter(x -> !isempty(x), b[2:end])
    end
    nmd = length(metadata)
    # widgets
    widgets = Dict{Symbol, Union{GtkReactive.Textarea, GtkReactive.Dropdown}}()
    for (k, v) in metadata
        if all(isempty.(v))
            widgets[Symbol(k)] = textarea("")
        else
            widgets[Symbol(k)] = dropdown(v)
        end
    end
    runadd = button("Add")
    # layout
    rung = Grid()
    for (i, kv) in enumerate(widgets)
        rung[0,i - 1] = Label(first(kv))
        rung[1,i - 1] = last(kv).widget
    end
    rung[0:1, nmd + 1] = widget(runadd)
    # function
    runsignal = map(runadd) do _
        Dict(k => value(v) for (k, v) in widgets)
    end


    # associations

    assg = Grid()
    as = loadAssociation(folder)
    as2 = map(merge(poisignal, runsignal), init = as) do x
        push!(as, x)
        as
    end
    as2h = map(as2) do a
        empty!(assg)
        for (x, t) in enumerate(a.pois)
            l = Label(string(t.name, ":", t.start.time.value, "-", t.stop.time.value))
            Gtk.GAccessor.angle(l, -90)
            assg[x, 0] = l
        end
        for (y, r) in enumerate(a.runs)
            assg[0, y] = Label(shorten(string(join(values(r.metadata), ":")..., ":", r.repetition), 10))
        end
        for (x, t) in enumerate(a.pois), (y, r) in enumerate(a.runs)
            key = (x, y)
            cb = checkbox(key in a.associations)
            cbh = map(signal(cb)) do checked²
                checked² ? push!(a.associations, key) : delete!(a.associations, key)
            end
            assg[x, y] = cb.widget
        end
        showall(win)
        return nothing
    end

    saves = Button("Save")
    saveh = signal_connect(saves, :clicked) do _
        save(folder, as)
        destroy(win)
    end

    quits = Button("Quit")
    quith = signal_connect(quits, :clicked) do _
        destroy(win)
    end

    #=saves = button("Save")
    quits = button("quit")
    saveh = map(saves, init = nothing) do _
        save(folder, as)
        destroy(win)
        nothing
    end
    quith = map(quits, init = nothing) do _
        exit()
        nothing
    end=#


    G = Grid()
    savequit = Box(:v)
    push!(savequit, saves, quits)
    G[0,0] = savequit
    G[0,1] = rung
    G[1,0] = poig
    G[1,1] = assg
    push!(win,G)
    showall(win)

    c = Condition()
    signal_connect(win, :destroy) do _
        notify(c)
    end
    wait(c)

    return folder
end

end # module
