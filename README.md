# Associations
`Associations.jl` helps scientists log video files and the experiments associated with these files.

[![Build Status](https://travis-ci.org/yakir12/Associations.jl.svg?branch=master)](https://travis-ci.org/yakir12/Associations.jl) [![Build status](https://ci.appveyor.com/api/projects/status/x6gx5vx5chjhchl7?svg=true)](https://ci.appveyor.com/project/yakir12/associations-jl)

[![codecov.io](http://codecov.io/github/yakir12/Associations.jl/coverage.svg?branch=master)](http://codecov.io/github/yakir12/Associations.jl?branch=master)

## How to install
1. If you haven't already, install [Julia v0.6 (Nightly builds)](https://julialang.org/downloads/) -> you should be able to launch it (some icon on the Desktop or some such)
2. Start Julia -> a Julia-terminal popped up
3. Copy: `Pkg.clone("git://github.com/yakir12/Associations.jl.git") && Pkg.build("Associations")` and paste it in the newly opened Julia-terminal, press Enter
4. To test the package (not necessary), copy: `Pkg.test("Associations")` and paste it in the Julia-terminal, press enter
5. You can close the Julia-terminal after it's done running

The user's interaction with this package is via GUI. You will find an executable file called `BeetleLog.jl` in your home directory. Double-click it to start the program.

## How to use

### Rational 
Recording, processing, and analysing videos of (behavioral) experiments usually includes some kind of manual work. This manual component might only include renaming and organizing video files, but could also mean manually tracking objects. The purpose of this package is to standardize your data at the earliest possible stage so that any subsequent manual involvement would be as easy and robust as possible. This allows for streamlining the flow of your data from the original raw-format video-files to the results of your analysis.

A typical workflow might look like this:
1. setup experiment 
2. run experiment & record videos 
3. rename videos 
4. organize files into categorical folders 
5. track objects in the videos 
6. collate tracking data into their experiemntal context 
7. process (camera) calibrations 
8. process the positions (normalizing directions, origin points, distances, relative sizes, relative landmarks, temporal events, etc.) 
9. run analysis on the positional data

The researcher is often required to manually perform some of these steps. While this manual envolvement is insignificant in small, one-person, projects, it could intoduce errors in larger projects. Indeed, in projects that involve multiple investigators, span across many years, and involve different experiments, manual organisation is simply not practical. 

The objective of this package is to constrain and control the points where manual involvement is unavoidable. By taking care of the manual component of the process as early as possible, we:
1. allow for greater flexability in subsequent stages of the analysis, 
2. garauntee that the data is kept at its original form,
3. pave the way for efficient automation of later stages in the analysis.

When logging videotaped experiments, it is useful to think of the whole process in terms of 4 different "entities":
1. **Video files**: the individual video files. One may contain a part, a whole, or multiple experimental runs. 
2. **POIs**: Points Of Interest (POI) you want to track in the video, tagging *when* in the video timeline they occur (the *where* in the video frame comes later). These could be: burrow, food, calibration sequence, trajectory track, barrier, landmark, etc.
3. **Runs**: These are the experimental runs. They differ from each other in terms of the treatment, location, repetition number, species, individual specimen, etc.
4. **Associations**: These describe how the **POI**s are associated to the **run**s. The calibration POI could for example be associated to a number of runs, while one run might be associated with multiple POIs.

By tagging the POIs, registering the various experimental runs you conducted, and noting the associations between these POIs and runs, we log *all* the information necessary for efficiently processing our data. 

### File hierarchy
To tag the POIs, the user must supply the program with a list of possible POI-tags. This list should include all the possible names of the POIs. Similarly, the program must have a list of all the possible metadata for the experimental runs. This is achieved with two necessary `csv` files: `poi.csv` and `run.csv`.

The program will process all the video files within a given folder. While the organization of the video files within this folder doesn't matter at all (e.g. video files can be spread across nested folders), **the folder *must* contain a folder called `metadata`. This `metadata` folder *must* contain the `poi.csv` and `run.csv` files.**

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
Each row describes a metadatum. The first field (fields are separated by a comma) describes the name of that specific metadatum. The fields following that are the possible values said metadatum can have. For instance, in the example above, `Condition` can take only two values: `Transfered` or `Covered`. In case the metadatum can not be limited to a finite number of discrete values and can only be described in free-text, leave the following fields empty (as in the case of the `Specimen ID` and `Comments` in the example above).

You can have as many or as few metadata as you like, keeping only the metadata and POIs that are relevant to your specific setups. This flexibility allows the user to keep different `poi.csv` and `run.csv` metadata files in each of their video-folders.

Note that apart from the requirement that a `metadata` folder contain the two `poi.csv` and `run.csv` files, **the values (i.e. fields) in these files must be delimited by a comma** (as shown in the example above). You can produce these two files using your favourite word editor (or excel), but make sure the file extension is `csv` and that the delimiter is a comma.

### Instructions
Once you've prepared the `metadata` folder and the two `csv` files, start the program. After launching the program, in the initial window, navigate and choose the folder that contains all the videos that you want to log (choose the folder itself, not a file inside the folder). A new window will appear, where you can add new POIs and Runs. In the POI section the user can choose a specific POI to log, a video file and time stamp where the POI starts, a video file and time stamp where the POI ends, and a comment (choosing a video file starts running it automatically, pressing `Add` adds the specific POI to the registry). In the Run section the user can edit a run by setting the correct metadata and pressing `Add`. After adding some POIs and Runs, the window will be populated with rows of runs and columns of POIs. Use the checkboxes to indicate the associations between the Runs and POIs. 

When done, press `Done`. While the program attempts to automatically extract the original filming date and time the video file was taped, it is *imperrative* that you make sure these are indeed correct. You will be presented with another window containing all the videos you logged and their dates and times. Adjust these accordingly (pressing the video filename starts playing the video). When finished press `Done`.

You will now find a new folder, `log`, in the video folder with 4 files in it: 
1. `files.csv`: all the file names, dates and times of when the file was recorded, and video duration in seconds (rounded up).
2. `pois.csv`: all the POI names, the video file where this POI started, the start time (in seconds), the video file where this POI ended, the stop time (in seconds), and comments.
3. `runs.csv`: All the metadata and their values in the logged runs. The last field is the number of replicates for each of the runs (calculated automatically).
4. `associations.csv`: A two column table where the first column is the POI number and the second column is the Run number (both relative to the row numbers in the `pois.csv` and `runs.csv` files). 
