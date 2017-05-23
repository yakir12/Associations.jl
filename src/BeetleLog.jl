#!/usr/bin/julia
using Associations
folder = Gtk.open_dialog("Select videos-folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
main(folder)
