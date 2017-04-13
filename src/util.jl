function shorten(s::String, k::Int)::String
    m = length(s)
    m > 2k + 1 || return s
    s[1:k]*"…"*s[(end-k + 1):end]
end
function shorten(vfs::Vector{String}, n)
    nmax = max(n, maximum(length.(vfs)))
    while n <= nmax
        if allunique(shorten(vf, n) for vf in vfs)
            break
        end
        n += 1
    end
    return Dict(shorten(vf, n) => vf for vf in vfs)
end

function openit(f::String)
    if isfile(f)
        if is_windows()
            run(`start $f`)
        elseif is_linux()
            run(`xdg-open $f`)
        elseif is_apple()
            run(`open $f`)
        else
            error("Unknown OS")
        end
    else
        systemerror("$f not found", true)
    end
end

