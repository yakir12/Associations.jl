using Associations
folder = Gtk.open_dialog("Select Dataset Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
poirun(folder)
checkvideos(folder)
