# MusicDL
(i didnt have original ideas for the name)
___

This is a bash wrapper for [OrpheusDL](https://github.com/OrfiTeam/OrpheusDL) and [Streamrip](https://github.com/nathom/streamrip). I love these two projects (go give them stars) but I wanted to add some features (automatically load/unload the python virtual environment, an interactive download mode...), and also to have a hub that let me use and manage the two of them easily: that's why this project exists.

This isn't intended to be a all-in-one tool, that also manages the configurations and all. The only real goal of this project is to make music download easier. All the other features (OrpheusDL modules management, OrpheusDL & Streamrip installation,etc) are only here because I thought it would be cool to have it. But I believe it would be overkill to add the possibility to edit the configurations through this program, that's why there is no features dedicated to that.


## How to use
- Clone the repository: `git clone https://github.com/likalium/musicdl`
- Go into the program directory: `cd musicdl`
- Run the script: `bash downloader.sh`

I recommend to put the script in it's own directory, so OrpheusDL, Streamrip, and the virtual environments are in the same folder and so things stay sorted

## Requirements
- Python (https://www.python.org/)
- bash (https://www.gnu.org/software/bash/)

## TODO
- [ ] Support more OrpheusDL options
- [ ] Support for search functions
- [ ] Add zfill function
- [ ] Make a python version for better compatibility with windows (I'll start working on it after the bash version is complete)
- [ ] Add functions to uninstall Streamrip or OrpheusDL
- [ ] Make functions for streamrip

## DONE
- [x] Help functions
- [x] OrpheusDL base features
- [x] Support for OrpheusDL modules
- [x] Add an option to force module download, even if the module is already installed
- [x] Add the function that show information about default values
