#!/usr/bin/julia
using Associations
folder = joinpath(Pkg.dir("Associations"), "test", "videofolder")
#folder = Gtk.open_dialog("Select videos-folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
#folder = open_dialog("Select a file in the videos-folder")
#folder, _ = splitdir(folder)
main(folder)
