#!/usr/bin/julia
using Associations
win = Gtk.Window("")
folder = Gtk.open_dialog("Select videos-folder", win, action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
main(folder)
