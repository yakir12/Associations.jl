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

    done = button("Done")
    g = Grid()
    g[0,0] = Label("File")
    g[1,0] = Label("Year")
    g[2,0] = Label("Month")
    g[3,0] = Label("Day")
    g[4,0] = Label("Hour")
    g[5,0] = Label("Minute")
    g[6,0] = Label("Second")
    ft2 = similar(ft)
    goodtimes = fill(Signal(true), length(ft))
    for (i, vf) in enumerate(ft)
        name = vf.file
        datetime = vf.datetime
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
        g[0,i] = play.widget
        g[1,i] = y.widget
        g[2,i] = m.widget
        g[3,i] = d.widget
        g[4,i] = H.widget
        g[5,i] = M.widget
        g[6,i] = S.widget
        dt = map(tuple, y, m, d, H, M, S)
        time_is_good = map(x -> isnull(Dates.validargs(DateTime, x..., 0)), dt) 
        goodtimes[i] = time_is_good
        goodtime = filterwhen(time_is_good, value(dt), dt)
        vf2 = map(goodtime) do x
            ft2[i] = VideoFile(vf.file, DateTime(x...))
        end
        tasksplay, resultsplay = async_map(nothing, signal(play)) do _
            openit(joinpath(folder, name))
        end
    end

    goodtime = map(&, goodtimes...)
    clicked = filterwhen(goodtime, Void(), signal(done))
    foreach(clicked,  init = nothing) do _
        save(folder, ft2)
        destroy(win)
    end

    g[0:6, length(ft) + 1] = widget(done)
    win = Window(g, "LogBeetle: Check videos", 1, 1)
    showall(win)

    c = Condition()
    signal_connect(win, :destroy) do _
        notify(c)
    end
    wait(c)
end

##################################################


function poirun(folder)

    poisignal = Signal(POI())
    metadatasignal = Signal(Run())
    added = merge(poisignal, metadatasignal)
    a = foldp(push!, loadAssociation(folder), added)

    c = Condition()
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
                   p.start.file == p.stop.file ? p.start.time <= p.stop.time : true, tt)

    newpoi = map(a, tt) do aa, pp
        !(pp in aa.pois)
    end

    good = map(goodtime, newpoi) do tf1, tf2
        tf1 && tf2
    end

    poisignal2 = filterwhen(good, POI(), t)

    bind!(poisignal, poisignal2, initial=false)

    # data
    tmp = readcsv(joinpath(folder, "metadata", "run.csv"))
    metadata = Dict{String, Vector{String}}()
    for i = 1:size(tmp,1)
        b = strip.(tmp[i,:])
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
    run_comment = textarea("")
    runadd = button("Add")
    # layout
    rung = Grid()
    for (i, kv) in enumerate(widgets)
        rung[0,i - 1] = Label(first(kv))
        rung[1,i - 1] = last(kv).widget
    end
    rung[0, nmd + 1] = Label("Comment")
    rung[1, nmd + 1] = widget(run_comment)
    rung[0:1, nmd + 2] = widget(runadd)
    # function
    metadatasignal2 = map(runadd, init = Run(Dict(k => value(v) for (k, v) in widgets), value(run_comment))) do _
        Run(Dict(k => value(v) for (k, v) in widgets), value(run_comment))
    end

    bind!(metadatasignal, metadatasignal2, initial=false)


    assdone = map(a) do aa
        empty!(gass)
        for (x, p) in enumerate(aa.pois)
            if p.visible
                file = MenuItem("_$(p.name) $(p.label)")
                filemenu = Menu(file)
                check_ = MenuItem("Check")
                checkh = signal_connect(check_, :activate) do _
                    for r in aa.runs
                        push!(aa.associations, (p, r))
                    end
                    push!(a, aa)
                end
                push!(filemenu, check_)
                uncheck_ = MenuItem("Uncheck")
                uncheckh = signal_connect(uncheck_, :activate) do _
                    for r in aa.runs
                        delete!(aa.associations, (p, r))
                    end
                    push!(a, aa)
                end
                push!(filemenu, uncheck_)
                #=hide_ = MenuItem("Hide")
                hideh = signal_connect(hide_, :activate) do _
                    p.visible = false
                    push!(a, aa)
                end
                push!(filemenu, hide_)=#
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
                    delete!(aa, p)
                end
                push!(filemenu, edit_)
                push!(filemenu, SeparatorMenuItem())
                delete = MenuItem("Delete")
                deleteh = signal_connect(delete, :activate) do _
                    delete!(aa, p)
                    push!(a, aa)
                end
                push!(filemenu, delete)
                mb = MenuBar()
                push!(mb, file)
                gass[x,0] = mb
            end
        end
        for (y, r) in enumerate(aa.runs)
            if r.run.visible
                file = MenuItem(string("_", shorten(string(join(values(r.run.metadata), ":")..., ":", r.repetition), 30)))
                filemenu = Menu(file)
                check_ = MenuItem("Check")
                checkh = signal_connect(check_, :activate) do _
                    for p in aa.pois
                        push!(aa.associations, (p, r))
                    end
                    push!(a, aa)
                end
                push!(filemenu, check_)
                uncheck_ = MenuItem("Uncheck")
                uncheckh = signal_connect(uncheck_, :activate) do _
                    for p in aa.pois
                        delete!(aa.associations, (p, r))
                    end
                    push!(a, aa)
                end
                push!(filemenu, uncheck_)
                #=hide_ = MenuItem("Hide")
                hideh = signal_connect(hide_, :activate) do _
                    r.visible = false
                    push!(a, aa)
                end
                push!(filemenu, hide_)=#
                edit_ = MenuItem("Edit")
                edith = signal_connect(edit_, :activate) do _
                    comment_win = Window("LogBeetle")
                    comment_comment = textarea(r.run.comment)
                    comment_done = button("Edit")
                    comment_v = Box(:v)
                    push!(comment_v, comment_comment, comment_done)
                    push!(comment_win, comment_v)
                    showall(comment_win)
                    foreach(comment_done, init = nothing) do _
                        edit_comment!(aa, r, value(comment_comment))
                        push!(a, aa)
                        destroy(comment_win)
                    end
                end
                    #=for (k, v) in widgets
                        push!(v, r.run.metadata[k])
                    end
                    push!(run_comment, r.run.comment)
                    delete!(aa, r)
                end=#
                push!(filemenu, edit_)
                push!(filemenu, SeparatorMenuItem())
                delete = MenuItem("Delete")
                deleteh = signal_connect(delete, :activate) do _
                    delete!(aa, r)
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
                key = (p, run)
                cb = checkbox(key in aa.associations)
                foreach(cb) do tf
                    tf ? push!(aa.associations, key) : delete!(aa.associations, key)
                end
                gass[x,y] = cb
            end
        end
        showall(win)
    end

    foreach(assdone) do _
        p = value(poisignal)
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


    saves = Button("Save")
    saveh = signal_connect(saves, :clicked) do _
        save(folder, value(a))
        if isempty(value(a))
            exit()
        end
        destroy(win)
    end

    clear = Button("Clear")
    clearh = signal_connect(clear, :clicked) do _
        empty!(value(a))
        push!(a, value(a))
    end

    quits = Button("Quit")
    quith = signal_connect(quits, :clicked) do _
        destroy(win)
        exit()
    end


    savequit = Box(:v)
    push!(savequit, saves, clear, quits)
    g[0,0] = Frame(savequit, "File")
    g[1,0] = Frame(poig, "POI")
    g[0,1] = Frame(rung, "Run")

    push!(win, g)
    showall(win)


    signal_connect(win, :destroy) do widget
        notify(c)
    end
    wait(c)

end
function main(folder::String) 
    poirun(folder)
    checkvideos(folder)
end
