# Associations

Associations.jl helps scientists log video files and the experiments associated with these files.

## How to install

1. Install [Julia](https://julialang.org/downloads/) -> you should be able to launch it (some icon on the Desktop or some such)
2. Start Julia -> a Julia-terminal popped up
3. Copy: `Pkg.clone("git://github.com/yakir12/Associations.jl.git") && Pkg.build("Associations")` and paste it in the newly opened Julia-terminal, press Enter
4. To test the package (not necessary), copy: `Pkg.test("Associations")` and paste it in the Julia-terminal, press enter
5. You can close the Julia-terminal after it's done running

To start the program, open a Julia-terminal, and paste:
```julia
using Associations
folder = Gtk.open_dialog("Select Dataset Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
poirun(folder)
checkvideos(folder)
```
If the the dialog box gets stuck, try this instead, where `PATH_TO_FOLDER` is the path to the folder where all the videos are:
```julia
using Associations
folder = PATH_TO_FOLDER
poirun(folder)
checkvideos(folder)
```
So replace `PATH_TO_FOLDER` with the path to the videos-folder.

## How to use

### Rational 
Recording, processing, and analysing videos of (behavioral) experiments usually includes some manual involvement. This manual component might only include renaming and organizing video files, but could also include manually tracking objects in the videos. The purpose of this package is to standardize your data at the earliest stage possible so that any subsequent manual involvement from your part would be as easy and robust as possible. This allows for streamlining the flow of your data from the original raw-format video files to the publishable figures showing the results of your analysis.

When logging videotaped experiments, it is useful to think of the whole process in terms of 4 different "entities":

1. **Video files**: the individual video files. One may contain a part, a whole, or multiple experimental runs. 
2. **POIs**: Points Of Interest (POI) you want to track in the video, tagging *when* in the video timeline they occur (the *where* in the video frame comes later). These could be: burrow, food, calibration sequence, trajectory track, barrier, landmark, etc.
3. **Runs**: These are the experimental runs. They differ from each other in terms of the treatment, location, repetition number, species, individual specimen, etc.
4. **Associations**: These describe how the **POI**s are associated to the **run**s. The calibration POI could for example be associated to a number of runs, while one run might be associated with multiple POIs.

By tagging the POIs, registering the various experimental runs you conducted, and noting the associations between these POIs and runs, we log *all* the information necessary for efficiently processing our data. 

### File hierarchy
To tag the POIs, the user must supply the program with a list of possible POI-tags. This list should include all the possible names of the POIs. Similarly, the program must have a list of all the possible metadata for the experimental runs. This is achieved with two necessary `csv` files: `poi.csv` and `run.csv`.

The program will process all the video files within a given folder. While the organization of the video files within this folder doesn't matter at all (e.g. video files can be spread across nested folders), the folder *must* contain a folder called `metadata`. This `metadata` folder contains the `poi.csv` and `run.csv` files. 

```
videos
│   some_file
│   some_video_file
│   ...
│
└───metadata
│       poi.csv
│       run.csv
│   
└───some_folder
    │   some_video_file
    │   other_video_file
    │   ...
    │   
    ...
```

The `poi.csv` file contains all the names of the possible POIs separated with a comma `,`. For example:

```
Nest, Home, North, South, Pellet, Search, Landmark, Gate, Barrier, Ramp
```
The `run.csv` file contains all the different categories affecting your runs as well as their possible values. Note how the following example file is structured:
```
Species, Scarabaeus lamarcki, Scarabaeus satyrus, Scarabaeus zambesianus, Scarabaeus galenus
Field station, Vryburg Stonehenge, BelaBela Thornwood, Pullen farm, Lund Skyroom
Experiment, Wind compass, Sun compass, Path integration, Orientation precision
Plot, Darkroom, Tent, Carpark, Volleyball court, Poolarea
Location, South Africa, Sweden, Spain
Condition, Transfered, Covered
Specimen ID,
Comments,
```
Each row describes a metadatum. The first field (fields are separated by a comma) describes the name of that specific metadatum. The following fields are the possible values said metadatum can have. In case the metadatum can not be limited to a finite number of discrete values and can only be described in free-text, leave the following fields empty (as in the case of the `Specimen ID` and `Comments` in the example above).

You can have as many or as few metadata as you like, keeping only the metadata and POIs that are relevant to your specific setups. This flexibility allows the user to keep different `poi.csv` and `run.csv` metadata files in each of their video-folders.

### Instructions
After launching the program, in the initial window, navigate and choose the folder that contains all the videos that you want to log (choose the folder itself, not a file inside the folder). A new window will appear, where you can add new POIs and Runs. In the POI section the user can choose a specific POI to log, a video file and time stamp where the POI starts, a video file and time stamp where the POI ends, and a comment (choosing a video file starts running it automatically, pressing `Add` adds the specific POI to the registry). In the Run section the user can edit a run by setting the correct metadata and pressing `Add`. After adding some POIs and Runs, the window will be populated with rows of runs and columns of POIs. Use the checkboxes to indicate the associations between the Runs and POIs. 

When done, press `Done`. While the program attempts to automatically extract the original filming date and time the video file was taped, it is *imperrative* that you make sure these are indeed correct. You will be presented with another window containing all the videos you logged and their dates and times. Adjust these accordingly (pressing the video filename starts playing the video). When finished press `Done`.

You will now find a new folder, `log`, in the video folder with 4 files in it: 
1. `files.csv`: all the file names, dates and times of when the file was recorded, and video duration in seconds (rounded up).
2. `pois.csv`: all the POI names, the video file where this POI started, the start time (in seconds), the video file where this POI ended, the stop time (in seconds), and comments.
3. `runs.csv`: All the metadata and their values in the logged runs. The last field is the number of replicates for each of the runs (calculated automatically).
4. `associations.csv`: A two column table where the first column is the POI number and the second column is the Run number (both relative to the row numbers in the `pois.csv` and `runs.csv` files). 
