using Gtk.ShortNames, GtkReactive, Associations
include(joinpath(Pkg.dir("Associations"), "src", "guifunctions.jl"))

folder = poirun()

checkvideos(folder)
