using Gtk.ShortNames, GtkReactive, Associations
function poigui(folder::String, win)
    # data
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
    add = button("Add")
    # layout
    setproperty!(s1.widget, :width_request, 5)
    setproperty!(m1.widget, :width_request, 5)
    setproperty!(h1.widget, :width_request, 5)
    setproperty!(s2.widget, :width_request, 5)
    setproperty!(m2.widget, :width_request, 5)
    setproperty!(h2.widget, :width_request, 5)
    g = Grid()
    g[0,0] = Label("POI")
    g[0,1] = Label("Start")
    g[2,0] = Label("H")
    g[3,0] = Label("M")
    g[4,0] = Label("S")
    g[0,2] = Label("Stop")
    g[5,0] = Label("Comment")
    g[1,0] = poi.widget
    g[1,1] = fstart.widget
    g[2,1] = h1.widget
    g[3,1] = m1.widget
    g[4,1] = s1.widget
    g[1,2] = fstop.widget
    g[2,2] = h2.widget
    g[3,2] = m2.widget
    g[4,2] = s2.widget
    g[5,1:2] = comment.widget
    g[6,0:2] = widget(add)
    push!(win, g)
    showall(win)
    visible(win, true)
    # function 
    tasksstart, resultsstart = async_map(nothing, signal(fstart)) do f²
        openit(joinpath(folder, files[f²].file))
        return nothing
    end
    tasksstop, resultsstop = async_map(nothing, signal(fstop)) do f²
        openit(joinpath(folder, files[f²].file))
        return nothing
    end
    tt = map(signal(poi), signal(fstart), signal(h1), signal(m1), signal(s1), signal(fstop), signal(h2), signal(m2), signal(s2), signal(comment)) do name², fstart², h1², m1², s1², fstop², h2², m2², s2², comment²
        try 
            start = Point(files[fstart²], sum(Dates.Second.([Dates.Hour(h1²), Dates.Minute(m1²), Dates.Second(s1²)])))
            stop = Point(files[fstop²], sum(Dates.Second.([Dates.Hour(h2²), Dates.Minute(m2²), Dates.Second(s2²)])))
            goodpoi = POI(name², start, stop, comment²)
            setproperty!(widget(add), :sensitive, true)
            goodpoi
        catch
            setproperty!(widget(add), :sensitive, false)
            POI()
        end
    end
    #poi = map(_ -> value(tt), add, init = value(tt))
    poi = map(add, init = value(tt)) do _
        #println("kaka")
        value(tt)
    end

    #=h = signal_connect(add, :clicked) do _
        push!(as.value, tt.value)
        push!(as, as.value)
    end=#
    return poi
end

function rungui(folder::String, win)
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
    add = button("Add")
    # layout
    g = Grid()
    for (i, kv) in enumerate(widgets)
        g[0,i - 1] = Label(first(kv))
        g[1,i - 1] = last(kv).widget
    end
    g[0:1, nmd + 1] = widget(add)
    push!(win, g)
    showall(win)
    visible(win, true)
    # function
    run = map(add) do _
        Dict(k => value(v) for (k, v) in widgets)
    end
    return run
end


function row(folder::String, name::String, datetime::DateTime)
    const baddate = DateTime()
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
        t² != baddate
    end
    tasksplay, resultsplay = async_map(nothing, play) do _
        openit(joinpath(folder, name))
    end
    return (play, y, m, d, H, M, S, dt, gd)
end

function checkvideos(folder::String, as::Association, win, g)
    # data

    a = Set{VideoFile}()
    for t in as.pois, vf in [t.start.file, t.stop.file]
        push!(a, vf)
    end
    ft = keys(a.dict)

    done = button("Done")
    #g = Grid()
    g[0,0] = Label("File")
    g[1,0] = Label("Year")
    g[2,0] = Label("Month")
    g[3,0] = Label("Day")
    g[4,0] = Label("Hour")
    g[5,0] = Label("Minute")
    g[6,0] = Label("Second")
    for (i, vf) in enumerate(ft)
        play, y, m, d, H, M, S, datetime, gooddate = row(folder, vf.file, vf.datetime[1])
        g[0,i] = play.widget
        g[1,i] = y.widget
        g[2,i] = m.widget
        g[3,i] = d.widget
        g[4,i] = H.widget
        g[5,i] = M.widget
        g[6,i] = S.widget
        foreach(sensitive -> setproperty!(widget(done), :sensitive, sensitive), gooddate)
        vfh = map(datetime) do dt²
            vf.datetime[1] = dt²
        end
    end
    g[0:6, length(ft) + 1] = widget(done)
    #win = Window(g, "LogBeetle: Check videos", 1, 1)
    showall(win)
    h = map(done, init = nothing) do _
        save(folder, as)
        destroy(win)
        nothing
    end
end

function spawnguis(win, A, winpoi, winrun, folder, clearh, saveh)
    as = loadAssociation(folder)
    p = poigui(folder, winpoi)
    r = rungui(folder, winrun)
    as2 = map(merge(p, r), init = as) do x
        push!(as, x)
        as
    end
    h = map(as2) do a
        empty!(A)
        for (x, t) in enumerate(a.pois)
            l = Label(string(t.name, ":", t.start.time.value, "-", t.stop.time.value))
            Gtk.GAccessor.angle(l, -90)
            A[x, 0] = l
        end
        for (y, r) in enumerate(a.runs)
            A[0, y] = Label(shorten(string(join(values(r.metadata), ":")..., ":", r.repetition), 10))
        end
        for (x, t) in enumerate(a.pois), (y, r) in enumerate(a.runs)
            key = (x, y)
            cb = checkbox(key in a.associations)
            cbh = map(signal(cb)) do checked²
                checked² ? push!(a.associations, key) : delete!(a.associations, key)
            end
            A[x, y] = cb.widget
        end
        showall(win)
        return nothing
    end
    hh = map(clearh, init = nothing) do _
        empty!(as)
        push!(as2, as)
        return nothing
    end
    hhh = map(saveh, init = nothing) do _
        empty!(A)
        destroy(winpoi)
        destroy(winrun)
        checkvideos(folder, as, win, A)
        return nothing
    end
    return nothing
end


#function main()
    #data
    # widgets
    file = MenuItem("_Session")
    filemenu = Menu(file)
    open_ = MenuItem("Open folder")
    push!(filemenu, open_)
    save_ = MenuItem("Save & check videos")
    push!(filemenu, save_)
    push!(filemenu, SeparatorMenuItem())
    clear_ = MenuItem("Clear session")
    push!(filemenu, clear_)
    quit_ = MenuItem("Quit program")
    push!(filemenu, quit_)
    mb = MenuBar()
    push!(mb, file)
    # layout
    b = Box(:v)
    A = Grid()
    push!(b, mb, A)
    win = Window(b, "LogBeetle")
    showall(win)
    winpoi = Window("LogBeetle: POI")
    visible(winpoi, false)
    winrun = Window("LogBeetle: Run")
    visible(winrun, false)
    # function
    folder = Signal("")
    hopen = signal_connect(open_, :activate) do _
        push!(folder, "/home/yakir/datasturgeon/projects/marie/projectmanagement/main/testvideos")
        #push!(folder, open_dialog("Select Dataset Folder", win, action=Gtk.GtkFileChooserAction.SELECT_FOLDER))
    end
    saveh = Signal(nothing)
    hsave = signal_connect(save_, :activate) do _
        push!(saveh, nothing)
    end
    clearh = Signal(nothing)
    hclear = signal_connect(clear_, :activate) do _
        push!(clearh, nothing)
    end
    hquit = signal_connect(quit_, :activate) do _
        destroy(winpoi)
        destroy(winrun)
        destroy(win)
    end

    h = map(folder, init = nothing) do f
        spawnguis(win, A, winpoi, winrun, f, clearh, saveh)
        return nothing
    end

    if !isinteractive()
        c = Condition()
        signal_connect(win, :destroy) do widget
            notify(c)
        end
        wait(c)
    end
#end

    #==##=h1, h2 = async_map(nothing, folder) do f
        for (root, dir, files) in walkdir(f)
            for file in files
                file = joinpath(root, file)
                println(hexdigest("MD5", readstring(file)))
            end
        end
    end=##==#



