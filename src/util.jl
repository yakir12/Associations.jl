function shorten(s::String, k::Int)::String
    m = length(s)
    m > 2k + 1 || return s
    s[1:k]*"…"*s[(end-k + 1):end]
end
function shorten(vfs::Vector{String}, nmin = 30)
    for k = nmin:max(nmin, maximum(length.(vfs)))
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

