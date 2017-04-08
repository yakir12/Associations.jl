function shorten(s::String, k::Int)::String
    m = length(s)
    m > 2k || return s
    s[1:k]*"…"*s[end-k + 1:end]
end
function shorten(vfs::Vector{VideoFile})
    for k = 20:max(20, maximum(length(vf.file) for vf in vfs))
        shortnames = Dict{String, VideoFile}()
        tooshort = false
        for vf in vfs
            key = shorten(vf.file, k)
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
