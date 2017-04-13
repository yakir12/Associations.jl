shorten(s::String, k::Int) = length(s) > 2k + 1 ? s[1:k]*"…"*s[(end-k + 1):end] : s
function shorten(vfs::Vector{String}, m)
    nmax = maximum(length.(vfs))
    n = min(m, nmax) - 1
    while n < nmax
        n += 1
        if allunique(shorten(vf, n) for vf in vfs)
            break
        end
        #println(n)
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

