#!/bin/bash

##########################################################################
#### Little script to symplify music download with Streamrip and OrpheusDL
##########################################################################

# Variables to use ANSI color codes while keeping the code readable
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Variables private to the script
# Possible values for modules (they're here because we print this array on OrpheusDL help
possibleModules=("beatport" "bugs" "deezer" "idagio" "jiosaavn" "kkbox" "napster" "nugs" "qobuz" "soundcloud" "tidal")
toDownload=() # Variable that will store the list of things to download
# Dedicated to store the state of the download directory before any download happen, so we know which files the download added
# Will be useful if the user requests to move the files after download or to modify them (eg with zfill)
backupDirState=()

# ENV VARIABLES
PLATFORM="qobuz" # Streaming platform to download music from
TYPE="album" # Media type. Only used for qobuz
ORPHEUSDIR="$PWD/OrpheusDL" # directory where orpheusdl script is located
STREAMRIPDIR="$PWD/streamrip" # directory where streamrip script is located
DEST="" # Destination to put the downloaded files at the end
ORPHEUSVENV="./.venv-orpheus" # Venv for orpheusdl
STREAMRIPVENV="./venv-streamrip" # Venv for streamrip

##################
# GLOBAL FUNCTIONS
##################

# Output an error with the wanted error message then exit
echoError() {
	echo -e "
${RED}ERROR${RESET}: $1
	"
	exit 1
}

# If the path given is a relative path but doesn't start with "./", we add it to avoid ambiguity
# Parameter given to the extension is the path to analyze
checkRelative() {
	path=$1 # We save the path so we can easily modify it
	if [[ "${path:0:2}" != "./" && "${path:0:1}" != "/" ]]; then
		path="./$path"
	fi
	echo "$path" # We use echo to return the new value
}

# Check is a directory exists, returns an error and exists if it doesn't, does nothing otherwise
# The first argument given to the function is the directory to check, the second is how to name the directory in the error message
checkDirectory () {
	directory="$(checkRelative "$1")" # Just in case
	if [[ ! -d "$directory" ]]; then
		echo -e "${RED}ERROR:${RESET} The directory given as $2 doesn't exists: ${YELLOW}$directory${RESET}"
		exit 1
	fi
}

# Function to let user choose the type of the content to download
# Argument is the type of media the user gave
assignType () {
	userType=$(echo "$1" | tr "\[A-Z\]" "\[a-z\]") # We make the type provided by the user lowercase, just in case
	# Type must be album, artist, label, track
	# For this we create a string that contains the possible arguments, separated by a space, and we compare it to a regex containing the type given by the user
	if [[ "album artist label track" =~ (^|[[:space:]])$userType($|[[:space:]]) ]]; then
		TYPE=$userType
	# If type is wrong, we exit with an error 
	else
		echoError "Invalid type argument: ${YELLOW}$1${RESET}"
	fi
}

# Function to let the user choose the directory to move their files after download completed
# Argument given to the function is the destination path for files
assignDest () {
	userDest="$(checkRelative "$1")" # We transform the path given into a clear relative path if needed (because it's prettier, and avoids confusion)
	# If the destination exists, we use it
	if [[ -e "$userDest" ]]; then
		DEST="$userDest"
	# If the destination doesn't exists, we output an error then exit
	else
		echoError "The directory you gave to put your files in after download doesn't exists: ${YELLOW}${userDest}${RESET}"
	fi
}

# Function to save the state of the download directory before downloads happen
# Argument given to the function is a directory
backupDir () {
	# The argument to give to the function is the directory were the downloads are put
	for i in "$1"/*; do
		backupDirState+=("$i")
	done
}


# Function to let the user choose the path to the virtual environment
# Argument given to the function is a path to a VENV
assignVenv () {
	userVenv="$(checkRelative "$1")" # We make the path into a clear relative path if needed
	# We output an error if the path doesn't exists
	if [[ ! -e "$userVenv" ]]; then
		echoError "The path you gave for the python virtual environment doesn't exists: ${YELLOW}$userVenv${RESET}"
	# We output an error if the file doesn't contain the file to activate the virtual environment
	elif [[ ! -e "$userVenv/bin/activate" ]]; then
		echoError "The path you gave is invalid for a virtual environment: It doesn't contain the file ${YELLOW}$userVenv/bin/activate${RESET}"
	# Otherwise we make the path given by the user a valid path
	else
		VENV="$userVenv"
	fi
}

# Check if an element is already in the toDownload array
# Argument given is the element we want to check if it's in the array
checkIfToDownload() {
	if [[ "${toDownload[*]}" =~ ($|[[:space:]])"$1"($|[[:space:]]) ]]; then
		echo 0 # We return 0 if the value is already in the table
	else
		echo 1 # Otherwise we return 1
	fi
}

# Function to add albums to download interactively
# Prompts the user to add an album, and exit when user input is empty
interactiveAddElements () {
	element=" "
	# Keep adding albums until no album is specified
	while [[ -n $element ]]; do
		echo "Content to add to the download list. Leave blank for stop adding and switch to downloading"
		echo -en "> "
		read -r element
		toDownload+=("$element")
	done
}

# Function to add elements, automatically choosing to do it interactively or not
addElements () {
	# If no value for download (next element is an argument starting with a "-", or no value is given after it at all), trigger interactive element adding
	if [[ "${2:0:1}" == "-" || $# == 0 ]]; then
		interactiveAddElements
	# Else, parse every element until it's an argument
	else
		# While the next element isn't an argument (aka doesn't starts with "-"), add the element to the array and shift elements to the left
		while [[ "${1:0:1}" != "-" && $# -gt 0 ]]; do
			# We add the element only if it's not already in the array
			if [[ $(checkIfToDownload "$1") == 1 ]]; then
				toDownload+=("$1")
			fi
			shift
		done
	fi
}

# Function to convert elements into links (for example if they're qobuz ids)
convertElements () {
	newToDownload=() # We create an array that will store the new values
	if [[ "$PLATFORM" == "qobuz" ]]; then
		for i in "${toDownload[@]}"; do
			# If element doesn't start with "https" then it's not a link, so it's an id
			if [[ "${i:0:5}" != "https" ]]; then
				newToDownload+=("https://play.qobuz.com/${TYPE}/${i}")
			else
				newToDownload+=("${i}")
			fi
		done
		toDownload=("${newToDownload[@]}") # We replace toDownload with the new values
	fi
}

# Useful links for music piracy
links () {
	echo -e "
${RED}Links for music piracy${RESET}

  ${GREEN}Firehawk52:${RESET} https://rentry.org/firehawk52						${YELLOW}[Qobuz tokens & Deezer ARLs, list of music ripping software]${RESET}
  ${GREEN}FMHY audio section:${RESET} https://fmhy.pages.dev/audiopiracyguide 				${YELLOW}[Various stuff for music piracy]${RESET}
  ${GREEN}FMHY audio section:${RESET} https://fmhy.net/audiopiracyguide 				${YELLOW}[Alternative link in case the other doesn't work]${RESET}
  ${GREEN}FMHY audio ripping subsection:${RESET} https://fmhy.pages.dev/audiopiracyguide#audio-ripping	${YELLOW}[Because a direct link is useful]${RESET}
  ${GREEN}Lucida:${RESET} https://lucida.to/								${YELLOW}[Website to download from various audio streaming platforms]${RESET}
"
}

# Help for "main menu"
mainHelp () {
	echo -e "
${RED}Usage:${RESET} $0 [OPTIONS] COMMAND

  ${YELLOW}Download a lot of stuff of the same type, easily${RESET}
	
  ${RED}Options:${RESET}
    ${GREEN}-h, --help${RESET}		Show this message and exit (you can use it after a command to see the options for the command)
    ${GREEN}-p, --platform${RESET}	Platform you want to download from
    ${GREEN}-m, --move${RESET}		Where to move the files after download. If unset, files won't be moved.
    ${GREEN}-v, --venv${RESET}		Path to the virtual environment
    ${GREEN}-t, --type${RESET}		Type of the media you want to download. ${RED}Required only if you want to download from Qobuz.${RESET}
    ${GREEN}-z, --zfill${RESET}		Add a zero before each downloaded track number if needed
  
  ${RED}Commands:${RESET}
    ${GREEN}streamrip${RESET}	Actions related to Streamrip
    ${GREEN}orpheus${RESET}	Actions related to OrpheusDL
    ${GREEN}links${RESET}	Print links to useful resources for music piracy
    ${GREEN}defaults${RESET}	Show default values for OrpheusDL virtual environment, media type, ...
	"
}

#####################
# ORPHEUSDL FUNCTIONS
#####################

# Help for OrpheusDL menu
orpheusHelp () {
	echo -e "
${RED}Usage:${RESET} $0 orpheus [OPTIONS]

  ${RED}Options:${RESET}
    ${GREEN}--module${RESET}		Install the wanted OrpheusDL module (supported: ${YELLOW}${possibleModules[*]}${RESET})
    ${GREEN}-h, --help${RESET}		Show this message and exit
    ${GREEN}-d, --download${RESET}	${YELLOW}Content${RESET} to download, each element being separated by a space. If ${YELLOW}unset${RESET}, switch to interactive download mode.
    ${GREEN}-i, --install${RESET}	Install OrpheusDL & creates a python virtualenv at $VENV


  ${RED}Definitions:${RESET}
    ${YELLOW}content${RESET}	Something to download. Can be an URL or, in case of qobuz, an album id, an artist id...
    ${YELLOW}unset${RESET}	To let the --download option unset, you can not put it in your command, or put it without any argument, and add options after it
"
}

# Function to check if the directory given as orpheus directory contains orpheus.py
# Argument given to the function is the directory to check
checkOrpheusDir () {
	userDir="$(checkRelative "$1")" # We save the user-provided directory in a variable, and we clearly make it relative if needed
	checkDirectory "$userDir" "OrpheusDL directory" # First of all we check if the user-provided directory exists
	# Returns an error & exit if orpheus.py cannot be found in the directory (do nothing otherwise)
	if [[ ! -e "$userDir/orpheus.py" ]]; then
		echoError "The directory you gave for OrpheusDL doesn't contain orpheus.py: ${YELLOW}${userDir}${RESET}"
	fi
}

# Function to download items with OrpheusDL
downloadOrpheus () {
	previousDir="$PWD" # We save the directory the program is executed from
	checkOrpheusDir "$ORPHEUSDIR" # We check if given OrpheusDL directory is valid before entering it
	source "$VENV/bin/activate" # Source the virtual environment
	# Entering into OrpheusDL directory, exit with an error in case something wrong happens (you cant be too careful i guess)
	cd "$ORPHEUSDIR" || (echo -e "${RED}ERROR:${RESET} Can't cd into the directory were OrpheusDL is supposed to be"; exit 1)
	for i in "${toDownload[@]}"; do
		python "$ORPHEUSDIR" "$i"
	done
	# going back to where the command has been launch; go to home if it fails; exit with an error if even this fails
	cd "$previousDir" ||
		(echo -e "${YELLOW}Warning${RESET}: Can't find the directory you launched the command from, cd'ing in $HOME"; cd "$HOME") ||
		echoError "Can't find nor the directory you were in, nor an home directory"
}

# Function to install OrpheusDL
installOrpheus () {
	echo -e "${GREEN}Cloning OrpheusDL...${RESET} \n"
	git clone "https://github.com/OrfiTeam/OrpheusDL" "$ORPHEUSDIR" || echoError "Can't clone OrpheusDL github repository. Maybe check your internet connection?"
	echo -e "${GREEN}Creating the python virtual environment for OrpheusDL at ${YELLOW}${VENV}${YELLOW}...${RESET} \n"
	python -m venv "$VENV" || echoError "Can't create the python virtual environment. Check python is correctly installed."
	echo -e "${GREEN}Installing OrpheusDL requirements...${RESET}"
	# Sourcing the virtual environment, exit with an error if something wrong happens
	source "$VENV/bin/activate" || echoError "Can't activate the virtual environment. Check your python installation."
	(cd OrpheusDL && pip install -r requirements.txt && python orpheus.py settings refresh && cd ..) ||
	echoError "Can't install OrpheusDL requirements. Check for your internet, your python installation, and if ${GREEN}${ORPHEUSDIR}${RESET} is the correct OrpheusDL location"
	deactivate # Deactivating the virtual environment
	echo -e "\n ${GREEN}Done!${RESET}"
}

# Function to install OrpheusDL modules
# Takes the modules the user wants to download as arguments
orpheusModules () {
	checkOrpheusDir "$ORPHEUSDIR" # We check orpheus directory given by the user
	# Entering into OrpheusDL directory, exit with an error in case something wrong happens (you cant be too careful i guess)
	cd "$ORPHEUSDIR" || echoError "Can't cd into the directory were OrpheusDL is supposed to be"
	# Before installing modules, we will build an array that stores the modules that are already installed
	installedModules=()
	# We loop over every possible module name
	for i in "${possibleModules[@]}"; do
		# We simply check if the module has a folder in OrpheusDL modules folder, and if it's not empty
		if [[ -d "./modules/$i" && -e "./modules/$i/*" ]]; then
			installedModules+=("$i")
		fi
	done
	modules=() # Will contain the modules to download
	# We parse until there is no module left to download (no more elements, or next element is an argument)
	# We always analyze only the first argument (add the end we shift elements to the left)
	while [[ $# -gt 0 && ${1:0:1} != "-" ]]; do
		currentModule="$(echo "$1" | tr "\[A-Z\]" "\[a-z\]")" # We make module name lowercase, just in case
		# If the module is already installed, we don't reinstall it
		if [[ "${installedModules[*]}" =~ (^|[[:space:]])"$currentModule"($|[[:space:]]) ]]; then
			echo "${YELLOW}Warning:${RESET} Module already installed. Passing..."
		# Else, we add the module to the download list only if it's a valid value
		elif [[ "${possibleModules[*]}" =~ (^|[[:space:]])"$currentModule"($|[[:space:]]) ]]; then
			modules+=("$currentModule")
		# Otherwise, we exit with an error
		else
			echoError "Invalid module name: ${YELLOW}${currentModule}${RESET}"
		fi
		shift
	done
	# Now that we have a list of valid module names, we simply loop over the array and download the wanted ones
	for m in "${modules[@]}"; do
		if [[ "$m" == "deezer" ]]; then
			url="heKVT/orpheusdl-deezer"
		elif [[ "$m" == "beatport" ]]; then
			url="Dniel97/orpheusdl-beatport"
		elif [[ "$m" == "bugs" ]]; then
			url="Dniel97/orpheusdl-bugsmusic"
		elif [[ "$m" == "idagio" ]]; then
			url="Dniel97/orpheusdl-idagio"
		elif [[ "$m" == "jiosaavn" ]]; then
			url="bunnykek/orpheusdl-jiosaavn"
		elif [[ "$m" == "kkbox" ]]; then
			url="uhwot/orpheusdl-kkbox"
		elif [[ "$m" == "napster" ]]; then
			url="OrfiDev/orpheusdl-napster"
		elif [[ "$m" == "nugs" ]]; then
			url="Dniel97/orpheusdl-nugs"
		elif [[ "$m" == "qobuz" ]]; then
			url="TheKVT/orpheusdl-qobuz"
		elif [[ "$m" == "soundcloud" ]]; then
			url="OrfiDev/orpheusdl-soundcloud"
		elif [[ "$m" == "tidal" ]]; then
			url="Dniel97/orpheusdl-tidal"
		fi
		# Now that we know the end of the github url, we can git clone the module
		echo -e "${GREEN}Cloning OrpheusDL's $m module...${RESET}"
		# Clone the module in the modules folder
		git clone --recurse-submodules "https://github.com/$url" "./modules/$m" ||
			echoError "Can't clone OrpheusDL's $m module github repository. Maybe check your internet connection?"
		echo -e "${GREEN}Updating OrpheusDL configuration...${RESET}"
		python orpheus.py || echoError "Can't update orpheus.py settings. Check your OrpheusDL installation"
	done
}

# Main command (like a hub) for OrpheusDL related argument parsing
orpheus () {
	# If no arguments at all, print help and exit
	if [[ $# == 0 ]]; then
		orpheusHelp
		exit 0
	fi
	# Choose weather to print help or not regarding of the arguments
	for i in "$@"; do
		# Arguments starts by "-" so we check only elements that starts by "-"
		if [[ "${i:0:1}" == "-" ]]; then
			# If any argument is "-h" or "--help", or if there is an unrecognized argument, print help and exit without doing anything
			if [[ "--help -h" =~ (^|[[:space:]])$i($|[[:space:]]) || ! "-i --install -d --download --module" =~ (^|[[:space:]])$i($|[[:space:]]) ]]; then
				orpheusHelp
				exit 0
			fi
		fi
	done
	# If VENV is unset, call it .venv-orpheus
	if [[ "$VENV" == "" ]]; then
		VENV="./.venv-orpheus"
	fi
	# If no help asked, we parse the arguments one by one. We parse until there is no argument left
	while [[ $# -gt 0 ]]; do
		case "$1" in
			"-d" | "--download")
				addElements "${@:2}" # We use everything after the -d/--download/--dl as an argument to addElement
				;;
			"-i" | "--install" )
				installOrpheus
				;;
			"--module")
				orpheusModules "${@:2}" # We pass all after the -m/--module as arguments
				;;
		esac
		# We do a simple shift, to remove the argument we just treated
		shift
		# We shift elements to the left until we encounter another argument, or until there is no argument left
		while [[ $# -gt 0 && "${1:0:1}" != "-" ]]; do
			shift
		done
	done
}

#####################
# STREAMRIP FUNCTIONS
#####################

# Help for streamrip submenu
streamripHelp () {
	echo -e "
${RED}Usage:${RESET} $0 streamrip [OPTIONS]

  ${RED}Options:${RESET}
    ${GREEN}-h, --help${RESET}		Show this message and exit
    ${GREEN}-v, --venv${RESET}		Path to the virtual environment
    ${GREEN}-p, --platform${RESET}	Platform you want to download from
    ${GREEN}-t, --type${RESET}		Type of the media you want to download
    ${GREEN}-i, --install${RESET}	Install Streamrip & creates a python virtualenv at $PWD/.streamrip
    ${GREEN}-d,--download${RESET}	Links to the content to download (separated by spaces)
    ${GREEN}-m, --move${RESET}		Where to move the files after download. If unset, files won't be moved
"
}

# Function to install Streamrip
installStreamrip () {
	echo -e "${GREEN}Creating the python virtual environment for Streamrip...${RESET} \n"
	python -m venv .venv-streamrip
	echo -e "${GREEN}Installing Streamrip...${RESET} \n"
	source ./.venv-streamrip/bin/activate # Sourcing the virtual environment
	pip install --upgrade streamrip
	deactivate # Deactivating the virtual environment
	echo -e "${GREEN}\nDone!${RESET}"
}

# Main command (like a hub) for Streamrip related argument parsing
streamrip () {
	# If no arguments at all, we print help
	if  [[ $# == 0 ]]; then
		streamripHelp
		exit 0 # We instantly exit after print help message
	fi
	# Parsing the arguments while there is arguments
	while [[ $# -gt 0 ]]; do
		print $#
		# We treat the first argument
		case $1 in
			"-i" | "--install")
				installStreamrip ;;
			# We print help if the users uses help flag, or if argument isn't recognized
			"-h" | "--help" | *)
				streamripHelp
				exit 0 ;; # We instantly exit after print help message
		esac
		# We shift the positional parameters to the left (2nd argument replaces 1st one, 3rd argument replaces 2nd...)
		shift
	done
}

################
# EXECUTION ZONE
################

# Parse all of the options before executing the commands (options start with "-", commands doesn't)
while [[ ${1:0:1} == "-" && $# -gt 0 ]];do
	case "$1" in
		"-m" | "--move"):
			assignDest "$2"
			;;
		"-p" | "--platform")
			PLATFORM="$(echo "$2" | tr "\[A-Z\]" "\[a-z\]")" # We make user input lowercase, just in case
			;;
		"-t" | "--type")
			assignType "$2" # The value after the argument is the value we want to give to this argument
			;;
		"-v" | "--venv")
			assignVenv "$2"
			;;
	esac
	# We shift two time to remove the argument and its value
	shift
	shift
done

# When we have finished parsing the options, we can execute the commands
case "$1" in
	"o" | "orpheus")
		orpheus "${@:2}" # We pass all the array, without the command and everything that's before
		# We launch downloading after all arguments got parsed and if needed
		if [[ ${#toDownload[@]} -gt 0 ]]; then
			downloadOrpheus 
		fi
		;;
	"s" | "streamrip")
		streamrip "${@:2}" # Same as for Orpheus
		;;
	"l" | "links")
		links
		;;
	*)
		mainHelp
		;;
esac
