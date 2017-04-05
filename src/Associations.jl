__precompile__()

module Associations

using Gtk.ShortNames, GtkReactive

export main

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

type File
    keep::Bool
    fname::String
    ext::String
    year::Int
    month::Int
    day::Int
    hour::Int
    minute::Int
    second::Int
    duration::Int #in seconds
    comment::String
end

function datetimeduration(fname::String)::Tuple{DateTime, Int}
    duration = "-" 
    dateTimeOriginal = "-" 
    createDate = "-" 
    modifyDate = "-"
    try 
        duration, dateTimeOriginal, createDate, modifyDate = strip.(split(readstring(`exiftool -T -duration -AllDates -n $fname`), '\t'))
    catch
        createDate = Dates.unix2datetime(ctime(fname))
        modifyDate = Dates.unix2datetime(mtime(fname))
    end
    duration = duration == "-" ? 10000000 : ceil(Int, parse(duration))
    datetime = DateTime(now())
    for i in [dateTimeOriginal, createDate, modifyDate]
        m = match(r"^(\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d)", i)
        m == nothing && continue
        datetime = min(datetime, DateTime(m[1], "yyyy:mm:dd HH:MM:SS"))
    end
    return (datetime, duration)
end

function uploadsaved(folder::String)::Vector{File}
    filesfile = joinpath(folder, "files.csv")
    f5 = File[]
    if isfile(filesfile) 
        f1 = readcsv(filesfile, String)
        for i = 1:size(f1,1)
            r = strip.(f1[i,:])
            dt = DateTime(r[3])
            push!(f5, File(true, r[1:2]..., Dates.Year(dt).value, Dates.Month(dt).value, Dates.Day(dt).value, Dates.Hour(dt).value, Dates.Minute(dt).value, Dates.Second(dt).value, parse(Int, r[4]), r[5:end]...))
        end
    end
    return f5
end


function getfiles(folder::String)::Vector{File}
    f5 = uploadsaved(folder)
    for (root, dir, files) in walkdir(folder)
        for file in files
            file[1] == '.' && continue
            f = joinpath(root, file)
            fname, ext = splitext(f)
            ext in exts || continue
            fname = relpath(fname, folder)
            any(f.fname == fname for f in f5) && continue
            dt, du = datetimeduration(f)
            push!(f5, File(true, fname, ext, Dates.Year(dt).value, Dates.Month(dt).value, Dates.Day(dt).value, Dates.Hour(dt).value, Dates.Minute(dt).value, Dates.Second(dt).value, du, ""))
        end
    end
    return f5
end

function shorten(s::String, k::Int)::String
    m = length(s)
    m > 2k || return s
    s[1:k]*"…"*s[end-k + 1:end]
end

function shorten(fs::Vector{File})
    for k = 20:max(20, maximum(length(f.fname) for f in fs))
        shortnames = Dict{String, File}()
        tooshort = false
        for f in fs
            key = shorten(f.fname, k)
            if haskey(shortnames, key)
                tooshort = true
                break
            end
            shortnames[key] = f
        end
        tooshort || return shortnames
    end
end



function gooddate(arg...)
    dt = [getproperty(x, :value, Int) for x in arg]
    try
        DateTime(dt...)
        return true
    catch error
        if isa(error, ArgumentError)
            return false
        else
            rethrow(error)
        end
    end
end
function row(shortname::String, f::File, done)
    cb = checkbox(true)
    l = Label(shortname)
    setproperty!(l, :tooltip_text, f.fname*f.ext)
    y = SpinButton(1:10000, value = f.year)
    m = SpinButton(1:12, value = f.month)
    d = SpinButton(1:31, value = f.day)
    H = SpinButton(0:23, value = f.hour)
    M = SpinButton(0:59, value = f.minute)
    S = SpinButton(0:59, value = f.second)
    comment = textarea("")
    cbh = map(cb) do tf
        map(x -> setproperty!(x, :sensitive, tf), [l, y, m, d, H, M, S, comment])
    end
    cbh = map(cb.signal) do s
        f.keep = s
    end
    yh = signal_connect(y, :changed) do wgt
        f.year = getproperty(wgt, :value, Int)
        setproperty!(done, :sensitive, gooddate(y, m, d, H, M, S))
    end
    mh = signal_connect(m, :changed) do wgt
        f.month = getproperty(wgt, :value, Int)
        setproperty!(done, :sensitive, gooddate(y, m, d, H, M, S))
    end
    dh = signal_connect(d, :changed) do wgt
        f.day = getproperty(wgt, :value, Int)
        setproperty!(done, :sensitive, gooddate(y, m, d, H, M, S))
    end
    Hh = signal_connect(H, :changed) do wgt
        f.hour = getproperty(wgt, :value, Int)
        setproperty!(done, :sensitive, gooddate(y, m, d, H, M, S))
    end
    Mh = signal_connect(M, :changed) do wgt
        f.minute = getproperty(wgt, :value, Int)
        setproperty!(done, :sensitive, gooddate(y, m, d, H, M, S))
    end
    Sh = signal_connect(S, :changed) do wgt
        f.second = getproperty(wgt, :value, Int)
        setproperty!(done, :sensitive, gooddate(y, m, d, H, M, S))
    end
    commenth = map(comment.signal) do txt
        f.comment = replace(txt, ',', ' ')
    end

    return (cb.widget, l, y, m, d, H, M, S, comment.widget)
end

function filedates(folder::String)

    files = shorten(getfiles(folder))
    #shortfiles = [shorten(v) for v in values(files)];

    # ok cancel
    done = button("Done")
    doneh = signal_connect(done.widget, :clicked) do _
        destroy(win0)
    end

    quit = Button("Quit")
    quith = signal_connect(quit, :clicked) do _
        exit()
    end

    # rows

    onoff = Box(:h)
    push!(onoff, done, quit)

    g = Grid()
    g[1,1] = Label("Keep")
    g[2,1] = Label("File")
    g[3,1] = Label("Year")
    g[4,1] = Label("Month")
    g[5,1] = Label("Day")
    g[6,1] = Label("Hour")
    g[7,1] = Label("Minute")
    g[8,1] = Label("Second")
    g[9,1] = Label("Comments")
    for (j, kv) in enumerate(files)
        a = row(kv..., done)
        for (i,ai) in enumerate(a)
            g[i,j + 1] = ai
        end
    end

    vbox = Box(:v)
    push!(vbox, g, onoff)

    win0 = Window("LogBeetle",5,5)
    push!(win0, vbox)
    showall(win0)

    c = Condition()
    signal_connect(win0, :destroy) do widget
        notify(c)
    end
    wait(c)

    return filter((_,v) -> v.keep, files)
end

const tags = strip.(vec(readcsv(joinpath(Pkg.dir("Associations"),"resources","tags.csv"), String)))
const specieses = strip.(vec(readcsv(joinpath(Pkg.dir("Associations"),"resources","species.csv"), String)))
const experiments = strip.(vec(readcsv(joinpath(Pkg.dir("Associations"),"resources","experiments.csv"), String)))
const fieldstations = strip.(vec(readcsv(joinpath(Pkg.dir("Associations"),"resources","fieldstations.csv"), String)))
const plots = strip.(vec(readcsv(joinpath(Pkg.dir("Associations"),"resources","plots.csv"), String)))

immutable Tag
    tag::String
    fstart::String
    start::DateTime
    fstop::String
    stop::DateTime
    comment::String
end

immutable Run
    fieldstation::String
    plot::String
    species::String
    experiment::String
    treatment::String
    specimen::String
    repetition::Int
    comment::String
end

goodduration(h1, m1, s1, h2, m2, s2) = DateTime(1,1,1, getproperty(h1, :value, Int), getproperty(m1, :value, Int), getproperty(s1, :value, Int)) <= DateTime(1,1,1, getproperty(h2, :value, Int), getproperty(m2, :value, Int), getproperty(s2, :value, Int))

function addtagfun(A, ts, rs, as, t)
    x = length(ts)
    l = Label(string(t.tag, Dates.format(t.start, "HH:MM:SS")))
    Gtk.GAccessor.angle(l, -90)
    hidetagb = Button(l)
    hidetagh = signal_connect(hidetagb, :clicked) do _
        deleteat!(A, x, :col)
    end
    A[x + 1,1] = hidetagb
    for y = 1:length(rs)
        state = (x,y) in as
        cb = checkbox(state)
        cbh = map(cb.signal) do tf
            #println(tf)
            key = (x, y)
            tf ? push!(as, key) : delete!(as, key)
        end
        A[x + 1, y + 1] = cb.widget
    end
end

function loadtags(folder, A, ts, rs, as)
    tags = joinpath(folder, "tags.csv")
    if isfile(tags)
        txt = readcsv(tags, String)
        for j in 1:size(txt, 1)
            i = strip.(txt[j,:])
            t = Tag(i[1:2]..., DateTime(i[3]), i[4], DateTime(i[5]), i[6])
            push!(ts, t)
            addtagfun(A, ts, rs, as, t)
        end
    end
end

function addrunfun(A, ts, rs, as, r)
    y = length(rs)
    l = Label(string(r.fieldstation, r.experiment, r.treatment, r.specimen))
    hiderunb = Button(l)
    hiderunh = signal_connect(hiderunb, :clicked) do _
        deleteat!(A, y, :row)
    end
    A[1,y + 1] = hiderunb
    for x = 1:length(ts)
        state = (x,y) in as
        cb = checkbox(state)
        cbh = map(cb.signal) do tf
            #println(tf)
            key = (x, y)
            tf ? push!(as, key) : delete!(as, key)
        end
        A[x + 1,y + 1] = cb.widget
    end
end

function loadruns(folder, A, ts, rs, as)
    runs = joinpath(folder, "runs.csv")
    if isfile(runs)
        txt = readcsv(runs, String)
        for j in 1:size(txt, 1)
            i = strip.(txt[j,:])
            repetition = parse(Int, i[7])
            r = Run(i[1:6]..., repetition, i[8])
            push!(rs, r)
            addrunfun(A, ts, rs, as, r)
        end
    end
end

function loadasss(folder, A, as)
    asss = joinpath(folder, "associations.csv")
    if isfile(asss)
        txt = readcsv(asss, Int)
        for j in 1:size(txt, 1)
            i = (txt[j, 1], txt[j, 2])
            push!(as, i)
        end
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

function main(;folder = clipboard())
    files = filedates(folder)

    # ok cancel
    done = button("Done")
    quit = button("Quit")
    # tags
    shortfiles = keys(files)
    tag = dropdown(tags)
    fstart = dropdown(shortfiles)
    fstop = dropdown(shortfiles)
    s1 = SpinButton(0:59)
    m1 = SpinButton(0:59)
    h1 = SpinButton(0:23)
    s2 = SpinButton(0:59)
    m2 = SpinButton(0:59)
    h2 = SpinButton(0:23)
    tagcomment = textarea("")
    addtag = button("Add")
    # runs
    fieldstation = dropdown(fieldstations; value = fieldstations[1])
    plot = dropdown(plots; value = plots[1])
    species = dropdown(specieses; value = specieses[1])
    experiment = dropdown(experiments; value = experiments[1])
    treatment = textbox("")
    specimen = textbox("")
    repetition = SpinButton(1:1000)
    runcomment = textarea("")
    addrun = button("Add")
    # layout
    taggrid = Grid()
    taggrid[1,1] = Label("Tag")
    taggrid[1,2] = Label("Start")
    taggrid[3,1] = Label("Hour")
    taggrid[4,1] = Label("Minute")
    taggrid[5,1] = Label("Second")
    taggrid[1,3] = Label("Stop")
    taggrid[6,1] = Label("Comment")
    taggrid[2,1] = tag.widget
    taggrid[2,2] = fstart.widget
    taggrid[3,2] = h1
    taggrid[4,2] = m1
    taggrid[5,2] = s1
    taggrid[2,3] = fstop.widget
    taggrid[3,3] = h2
    taggrid[4,3] = m2
    taggrid[5,3] = s2
    taggrid[6,2:3] = tagcomment.widget
    taggrid[7,1:3] = addtag.widget

    rungrid = Grid()
    rungrid[1,1] = Label("Field St.")
    rungrid[1,2] = Label("Plot")
    rungrid[1,3] = Label("Species")
    rungrid[1,4] = Label("Exp.")
    rungrid[1,5] = Label("Treatment")
    rungrid[1,6] = Label("Specimen")
    rungrid[1,7] = Label("Rep.")
    rungrid[1,8] = Label("Comment")
    rungrid[2,1] = fieldstation.widget
    rungrid[2,2] = plot.widget
    rungrid[2,3] = species.widget
    rungrid[2,4] = experiment.widget
    rungrid[2,5] = treatment.widget
    rungrid[2,6] = specimen.widget
    rungrid[2,7] = repetition
    rungrid[2,8] = runcomment.widget
    rungrid[1:2,9] = addrun.widget

    g = Grid()
    A = Grid()

    ts = Tag[]
    rs = Run[]
    as = Set{Tuple{Int, Int}}()

    loadasss(folder, A, as)
    loadtags(folder, A, ts, rs, as)
    loadruns(folder, A, ts, rs, as)

    onoff = Grid()
    onoff[1,1] = done.widget
    onoff[2,1] = quit.widget
    setproperty!(onoff, :column_homogeneous, true)
    g[1,1] = onoff
    g[2,1] = taggrid
    g[1,2] = rungrid
    g[2,2] = A

    win0 = Window("LogBeetle")
    push!(win0, g)
    showall(win0)
    # function
    quith = signal_connect(quit.widget, :clicked) do _
        destroy(win0)
    end
    #stopfileupdate = map(fstart) do f
    #push!(fstop.signal, f)
    #end

    openvideo = map(fstart; init=nothing) do f
        @async openit(joinpath(folder, files[f].fname*files[f].ext))
        return nothing
    end

    openvideo = map(fstop; init=nothing) do f
        @async openit(joinpath(folder, files[f].fname*files[f].ext))
        return nothing
    end

    times = [h1, m1, s1, h2, m2, s2]
    h1h = [signal_connect(_ -> setproperty!(addtag, :sensitive, fstart.signal.value !== fstop.signal.value || goodduration(times...)), x, :changed) for x in times]
    fsts = [fstart.widget, fstop.widget]
    h2h = [signal_connect(_ -> setproperty!(addtag, :sensitive, fstart.signal.value !== fstop.signal.value || goodduration(times...)), x, :changed) for x in fsts]


    addtagh = signal_connect(addtag.widget, :clicked) do _
        t = tag.signal.value
        f1 = files[fstart.signal.value]
        start = DateTime(f1.year, f1.month, f1.day, f1.hour, f1.minute, f1.second) + Dates.CompoundPeriod([Dates.Hour(getproperty(h1, :value, Int)), Dates.Minute(getproperty(m1, :value, Int)), Dates.Second(getproperty(s1, :value, Int))])
        f2 = files[fstop.signal.value]
        stop = DateTime(f2.year, f2.month, f2.day, f2.hour, f2.minute, f2.second) + Dates.CompoundPeriod([Dates.Hour(getproperty(h2, :value, Int)), Dates.Minute(getproperty(m2, :value, Int)), Dates.Second(getproperty(s2, :value, Int))])
        comment = replace(tagcomment.signal.value, ',', ' ')
        t = Tag(t, f1.fname*f1.ext, start, f2.fname*f2.ext, stop, comment)
        push!(ts, t)

        addtagfun(A, ts, rs, as, t)
        showall(win0)
    end

    addrunh = signal_connect(addrun.widget, :clicked) do _
        r = Run(fieldstation.signal.value, plot.signal.value, species.signal.value, experiment.signal.value, treatment.signal.value, specimen.signal.value, getproperty(repetition, :value, Int), replace(runcomment.signal.value, ',', ' '))
        push!(rs, r)
        addrunfun(A, ts, rs, as, r)
        showall(win0)
    end
    doneh = signal_connect(done.widget, :clicked) do _
        open(joinpath(folder, "files.csv"), "w") do o
            println(o, "# file, date and time, video duration (sec), comments")
            for f in values(files)
                f.keep || continue
                println(o, f.fname, ", ", f.ext, ", ", DateTime(f.year, f.month, f.day, f.hour, f.minute, f.second), ", ", f.duration, ", ", f.comment)
            end
        end
        open(joinpath(folder, "tags.csv"), "w") do o
            println(o, "# tag, start video, start date and time, stop video, stop date and time, comments")
            for t in ts
                println(o, t.tag, ", ", t.fstart, ", ", t.start, ", ", t.fstop, ", ", t.stop, ", ", t.comment)
            end
        end
        open(joinpath(folder, "runs.csv"), "w") do o
            println(o, "# field station, plot, species, experiment, treatment, specimen, repetition, run")
            for r in rs
                println(o, r.fieldstation, ", ", r.plot, ", ", r.species, ", ", r.experiment, ", ", r.treatment, ", ", r.specimen, ", ", r.repetition, ", ", r.comment)
            end
        end
        open(joinpath(folder, "associations.csv"), "w") do o
            println(o, "# tag row, run row")
            for (t,r) in as
                println(o, t, ", ", r)
            end
        end
        destroy(win0)
    end

    c = Condition()
    signal_connect(win0, :destroy) do widget
        notify(c)
    end
    wait(c)
end

end # module
