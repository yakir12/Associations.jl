#!/usr/bin/julia
using Gtk, Associations
folder = "/home/yakir/.julia/v0.6/Associations/test/videofolder"
#folder = Gtk.open_dialog("Select videos-folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
#folder = open_dialog("Select a file in the videos-folder")
#folder, _ = splitdir(folder)
poirun(folder)
checkvideos(folder)
