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

    files = shorten(getVideoFiles(folder), 30)
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

    foreach(poisignal) do p
        if p.start.file == p.stop.file
            dt = DateTime() + p.stop.time
            push!(h1, Dates.Hour(dt).value)
            push!(m1, Dates.Minute(dt).value)
            push!(s1, Dates.Second(dt).value)

            d = dt + p.stop.time - p.start.time

            push!(h2, Dates.Hour(d).value)
            push!(m2, Dates.Minute(d).value)
            push!(s2, Dates.Second(d).value)
        end
    end

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
            assg[0, y] = Label(shorten(string(join(values(r.metadata), ":")..., ":", r.repetition), 30))
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
    G[0,0] = Frame(savequit, "File")
    G[0,1] = Frame(rung, "Run")
    G[1,0] = Frame(poig, "POI")
    G[1,1] = Frame(assg, "Associations")
    push!(win,G)
    showall(win)

    c = Condition()
    signal_connect(win, :destroy) do _
        notify(c)
    end
    wait(c)

    return folder
end

