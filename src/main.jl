using Associations
folder = isempty(ARGS) ? Gtk.open_dialog("Select Dataset Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER) : ARGS[1]
poirun(folder)
checkvideos(folder)
