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
        tasksplay, resultsplay = async_map(nothing, signal(play)) do _
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
    gass = Grid()
    g = Grid()
    g[1,1] = Frame(gass, "Associations")



    files = shorten(getVideoFiles(folder), 30)
    points = strip.(vec(readcsv(joinpath(folder, "metadata", "poi.csv"), String)))
    shortfiles = collect(keys(files))
    function build_poi_gui(p = points[1], f1 = shortfiles[1], f2 = shortfiles[1], ss1 = 0, mm1 = 0, hh1 = 0, ss2 = 0, mm2 = 0, hh2 = 0, l = "", c = "")
        # widgets
        poi = dropdown(points, value = p)
        fstart = dropdown(shortfiles, value = f1)
        fstop = dropdown(shortfiles, value = f2)
        s1 = spinbutton(0:59, orientation = "v", value = ss1)
        m1 = spinbutton(0:59, orientation = "v", value = mm1)
        h1 = spinbutton(0:23, orientation = "v", value = hh1)
        s2 = spinbutton(0:59, orientation = "v", value = ss2)
        m2 = spinbutton(0:59, orientation = "v", value = mm2)
        h2 = spinbutton(0:23, orientation = "v", value = hh2)
        poilabel = textarea(l)
        comment = textarea(c)
        poiadd = button("Add")
        # layout
        setproperty!(widget(s1), :width_request, 5)
        setproperty!(widget(m1), :width_request, 5)
        setproperty!(widget(h1), :width_request, 5)
        setproperty!(widget(s2), :width_request, 5)
        setproperty!(widget(m2), :width_request, 5)
        setproperty!(widget(h2), :width_request, 5)
        poig = Grid()
        poig[5,0] = Label("POI:")
        poig[0,1] = Label("Start:")
        poig[2,0] = Label("H")
        poig[3,0] = Label("M")
        poig[4,0] = Label("S")
        poig[0,2] = Label("Stop:")
        poig[5,1] = Label("Label:")
        poig[5,2] = Label("Comment:")
        poig[6,0] = widget(poi)
        poig[1,1] = widget(fstart)
        poig[2,1] = widget(h1)
        poig[3,1] = widget(m1)
        poig[4,1] = widget(s1)
        poig[1,2] = widget(fstop)
        poig[2,2] = widget(h2)
        poig[3,2] = widget(m2)
        poig[4,2] = widget(s2)
        poig[6,1] = widget(poilabel)
        poig[6,2] = widget(comment)
        poig[0:1,0] = widget(poiadd)
        setproperty!(poig, :row_spacing, 5)
        return (poig, poi, fstart, fstop, s1, m1, h1, s2, m2, h2, comment, poilabel, poiadd)
    end
    poig, poi, fstart, fstop, s1, m1, h1, s2, m2, h2, comment, poilabel, poiadd = build_poi_gui()
    # function 
    tasksstart, resultsstart = async_map(nothing, signal(fstart)) do f²
        openit(joinpath(folder, files[f²]))
        return nothing
    end
    tasksstop, resultsstop = async_map(nothing, signal(fstop)) do f²
        openit(joinpath(folder, files[f²]))
        return nothing
    end
    tt = map(poi, fstart, h1, m1, s1, fstop, h2, m2, s2, poilabel, comment) do poi², fstart², h1², m1², s1², fstop², h2², m2², s2², poilabel², comment²
        p1 = Point(files[fstart²], h1², m1², s1²)
        p2 = Point(files[fstop²], h2², m2², s2²)
        POI(poi², p1, p2, poilabel², comment²)
    end
    t = map(_ -> value(tt), poiadd, init = value(tt))


    goodtime = map(p -> 
                   #!haskey(poiindex, p) && 
                   (p.start.file == p.stop.file ? p.start.time <= p.stop.time : true), tt)


    poisignal = filterwhen(goodtime, POI(), t)


    #=t1, t2 = async_map(nothing, poisignal) do p
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
        return nothing
    end=#
    foreach(poisignal) do p
        if p.start.file == p.stop.file
            dt = DateTime() + p.stop.time
            signal(h1).value = Dates.Hour(dt).value
            signal(m1).value = Dates.Minute(dt).value
            signal(s1).value = Dates.Second(dt).value
            d = dt + p.stop.time - p.start.time
            signal(h2).value = Dates.Hour(d).value
            signal(m2).value = Dates.Minute(d).value
            signal(s2).value = Dates.Second(d).value
        end
    end

    #=poiadd = button("a")
    poig = Grid()
    poig[0,0] = widget(poiadd)
    poisignal = map(_ -> POI(), poiadd)=#
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
    metadatasignal = map(runadd, init = Dict(k => value(v) for (k, v) in widgets)) do _
        Dict(k => value(v) for (k, v) in widgets)
    end

    added = merge(poisignal, metadatasignal)
    a = map(added, init = loadAssociation(folder)) do x
        push!(value(a), x)
    end

    foreach(a) do aa
        empty!(gass)
        for (x, p) in enumerate(aa.pois)
            if p.visible
                file = MenuItem("_$(p.label) $x")
                filemenu = Menu(file)
                check_ = MenuItem("Check")
                checkh = signal_connect(check_, :activate) do _
                    for y = 1:aa.nruns
                        push!(aa.associations, (x, y))
                    end
                    push!(a, aa)
                end
                push!(filemenu, check_)
                uncheck_ = MenuItem("Uncheck")
                uncheckh = signal_connect(uncheck_, :activate) do _
                    for y = 1:aa.nruns
                        delete!(aa.associations, (x, y))
                    end
                    push!(a, aa)
                end
                push!(filemenu, uncheck_)
                hide_ = MenuItem("Hide")
                hideh = signal_connect(hide_, :activate) do _
                    p.visible = false
                    push!(a, aa)
                end
                push!(filemenu, hide_)
                edit_ = MenuItem("Edit")
                edith = signal_connect(edit_, :activate) do _
                    push!(poi, p.name)
                    push!(fstart, findshortfile(p.start.file, files))
                    push!(fstop, findshortfile(p.stop.file, files))
                    dt1 = DateTime() + p.start.time
                    push!(s1, Dates.Second(dt1).value)
                    push!(m1, Dates.Minute(dt1).value)
                    push!(h1, Dates.Hour(dt1).value)
                    dt2 = DateTime() + p.stop.time
                    push!(s2, Dates.Second(dt2).value)
                    push!(m2, Dates.Minute(dt2).value)
                    push!(h2, Dates.Hour(dt2).value)
                    push!(poilabel, p.label)
                    push!(comment, p.comment)
                    deleteat!(aa, p)
                end
                push!(filemenu, edit_)
                push!(filemenu, SeparatorMenuItem())
                delete = MenuItem("Delete")
                deleteh = signal_connect(delete, :activate) do _
                    deleteat!(aa, p)
                    push!(a, aa)
                end
                push!(filemenu, delete)
                mb = MenuBar()
                push!(mb, file)
                gass[x,0] = mb
            end
        end
        for (y, r) in enumerate(aa.runs)
            if r.visible
                file = MenuItem("_$(shorten(string(join(values(r.metadata), ":")..., ":", r.repetition), 30)) $y")
                filemenu = Menu(file)
                check_ = MenuItem("Check")
                checkh = signal_connect(check_, :activate) do _
                    for x = 1:aa.npois
                        push!(aa.associations, (x, y))
                    end
                    push!(a, aa)
                end
                push!(filemenu, check_)
                uncheck_ = MenuItem("Uncheck")
                uncheckh = signal_connect(uncheck_, :activate) do _
                    for x = 1:aa.npois
                        delete!(aa.associations, (x, y))
                    end
                    push!(a, aa)
                end
                push!(filemenu, uncheck_)
                hide_ = MenuItem("Hide")
                hideh = signal_connect(hide_, :activate) do _
                    r.visible = false
                    push!(a, aa)
                end
                push!(filemenu, hide_)
                edit_ = MenuItem("Edit")
                edith = signal_connect(edit_, :activate) do _
                    for (k, v) in widgets
                        push!(v, r.metadata[k])
                    end
                    deleteat!(aa, r)
                end
                push!(filemenu, edit_)
                push!(filemenu, SeparatorMenuItem())
                delete = MenuItem("Delete")
                deleteh = signal_connect(delete, :activate) do _
                    deleteat!(aa, r)
                    push!(a, aa)
                end
                push!(filemenu, delete)
                mb = MenuBar()
                push!(mb, file)
                gass[0,y] = mb
            end
        end
        for (x, p) in enumerate(aa.pois), (y, run) in enumerate(aa.runs)
            if p.visible
                key = (x,y)
                cb = checkbox(key in aa.associations)
                foreach(cb) do tf
                    tf ? push!(aa.associations, key) : delete!(aa.associations, key)
                end
                gass[x,y] = cb
            end
        end
        showall(win)
    end


    saves = Button("Save")
    saveh = signal_connect(saves, :clicked) do _
        save(folder, value(a))
        destroy(win)
    end

    quits = Button("Quit")
    quith = signal_connect(quits, :clicked) do _
        destroy(win)
    end


    savequit = Box(:v)
    push!(savequit, saves, quits)
    g[0,0] = Frame(savequit, "File")
    g[1,0] = Frame(poig, "POI")
    g[0,1] = Frame(rung, "Run")

    push!(win, g)
    showall(win)


    c = Condition()
    signal_connect(win, :destroy) do widget
        notify(c)
    end
    wait(c)

end
