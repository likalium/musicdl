#!/bin/bash

#### Little script to symplify music download with Streamrip and OrpheusDL

# Variables to use ANSI color codes while keeping the code readable
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

##################
# GLOBAL FUNCTIONS
##################

# VARIABLES
toDownload=() # Variable that will store the list of things to download
PLATFORM="qobuz" # Streaming platform to download music from
TYPE="album" # Media type. Only used for qobuz
ORPHEUSDIR="$PWD/OrpheusDL" # directory where orpheusdl script is located
STREAMRIPDIR="$PWD/streamrip" # directory where streamrip script is located
DEST="" # Destination to put the downloaded files at the end
ORPHEUSVENV="./.venv-orpheus" # Venv for orpheusdl
STREAMRIPVENV="./venv-streamrip" # Venv for streamrip

# Function to let user choose the type of the content to download
assignType () {
	userType=$(echo "$1" | tr [A-Z] [a-z]) # We make the type provided by the user lowercase, just in case
	# Type must be album, artist, label, track
	# For this we create a string that contains the possible arguments, separated by a space, and we compare it to a regex containing the type given by the user
	if [[ "album artist label track" =~ (^|[[:space:]])$userType(^|[[:space:]]) ]]; then
		TYPE=$userType
	# If type is wrong, we exit with an error 
	else
		echo -e "${RED}ERROR${RESET}: Invalid type argument: ${YELLOW}$1${RESET}"
		exit 1
	fi
}

# Function to let the user choose the path to the virtual environment
assignVenv () {
	# We check that the path exists
	if [[ -e "$1" ]]; then
		VENV=$1
	# We output with an error if the path doesn't exists
	else
		echo -e "${RED}ERROR${RESET}: The path you gave for the python virtual environment doesn't exists: ${YELLOW}$1${RESET}"
		exit 1
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

# Function to add elements, automatically choosing to do it interactivement or not
addElements () {
	# If no value for download (next element is an argument, starting with a "-", or no value is given at all), trigger interactive element adding
	if [[ "${2:0:1}" == "-" || $# == 0 ]]; then
		interactiveAddElements
		# Else, parse every element until it's an argument
	else
		# We shift to the next element to avoid adding the download argument (-d/--download/--dl) to the "things to download" array
		shift
		# While the next element isn't an argument (aka doesn't starts with "-"), add the element to the array and shift elements to the left
		while [[ "${1:0:1}" == "-" ]]; do
			toDownload=("$1")
			shift
		done
	fi
}

# Function to convert elements into links (for example if they're qobuz ids)
convertElements () {
	newToDownload=() # We create an array that will store the new values
	if [[ $PLATFORM == "qobuz" ]]; then
		for i in "${toDownload[@]}"; do
			# If element doesn't start with "https" then it's not a link, so it's an id
			if [[ "${i:0:5}" != "https" ]]; then
				newToDownload+=("https://play.qobuz.com/${TYPE}/${i}")
			else
				newToDownload+=("${i}")
			fi
		done
	fi
	toDownload=("${newToDownload[@]}") # We replace toDownload with the new values
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
    ${GREEN}-v, --venv${RESET}		Path to the virtual environment
    ${GREEN}-p, --platform${RESET}	Platform you want to download from
    ${GREEN}-t, --type${RESET}		Type of the media you want to download. ${RED}Required only if you want to download from Qobuz.${RESET}
  
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
    ${GREEN}--module${RESET}	Install the OrpheusDL modules located at the given Github link
    ${GREEN}-h, --help${RESET}		Show this message and exit
    ${GREEN}-p, --platform${RESET}	Platform you want to download from
    ${GREEN}-t, --type${RESET}		Type of the media you want to download
    ${GREEN}-i, --install${RESET}	Install OrpheusDL & creates a python virtualenv at $PWD/.orpheusdl
    ${GREEN}-d, --download${RESET}	${YELLOW}Content${RESET}, each element being separated by a space. If unset, switch to interactive download mode.
	${GREEN}-m, --move${RESET}	Where to move the files after download. If unset, files won't be moved.


  ${RED}Definitions:${RESET}
    ${YELLOW}content${RESET}	Something to download. Can be an URL or, in case of qobuz, an album id, an artist id...
"
}

# Function to download items with OrpheusDL
downloadOrpheus () {
	source "$VENV" # Source the virtual environment
	for i in "${toDownload[@]}"; do
		python "$ORPHEUSDIR" "$i"
	done
}

# Function to install OrpheusDL
installOrpheus () {
	echo -e "${GREEN}Cloning OrpheusDL...${RESET} \n"
	git clone "https://github.com/OrfiTeam/OrpheusDL"
	echo -e "${GREEN}Creating the python virtual environment for OrpheusDL...${RESET} \n"
	python -m venv $VENV
	echo -e "${GREEN}Installing OrpheusDL requirements...${RESET}"
	source $VENV/bin/activate # Sourcing the virtual environment
	cd OrpheusDL && pip install -r requirements.txt && python3 orpheus.py settings refresh && cd ..
	deactivate # Deactivating the virtual environment
	echo -e "\n ${GREEN}Done!${RESET}"
}

# Main command (like a hub) for OrpheusDL related commands
orpheus () {
	# If no arguments at all, print help and exit
	if [[ $# == 0 ]]; then
		orpheusHelp
		exit 0
	fi
	# If any argument is "-h" or "--help", or if there is an unrecognized argument, print help and exit without doing anything
	for i in "$@"; do
		# Arguments starts by "-" so we check only elements that starts by "-"
		if [[ "${i:0:1}" == "-" ]]; then
			if [[ "--help -h" =~ (^|[[:space:]])$i(^|[[:space:]]) || ! "-p --platform -d --download -m --module" =~ (^|[[:space:]])$i(^|[[:space:]]) ]]; then
				orpheusHelp
				exit 0
			fi
		fi
	done
	# If no help asked, we parse the arguments one by one. We parse until there is no argument left
	while [[ $# -gt 0 ]]; do
		case "$1" in
			"-d" | "--download" | "--dl")
				addElements "${@:2}" # We use everything after the -d/--download/--dl as an argument to addElement
				;;
			"-i" | "--install" )
				installOrpheus
		esac
		# We shift elements to the left until we encounter an argument, or until there is no argument left
		while [[ $# -gt 0 || "${1:0:1}" != "-" ]]; do
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

# Main command (like a hub) for Streamrip related commands
streamrip () {
	# If no arguments at all, we print help
	if  [[ $# == 0 ]]; then
		streamripHelp
		exit 0 # We instantly exit after print help message
	fi
	# Parsing the arguments while there is arguments
	while [[ $# -gt 0 ]]; do
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

# Parse all of the options before executing the commands (options start with "-", commands doesn't
while [[ ${1:0:1} == "-" ]];do
	case "$1" in
		"-t" | "--type")
			assignType "$2" # The value after the argument is the value we want to give to this argument
			;;
		"-v" | "--venv")
			assignVenv "$2"
			;;
		"-p" | "--platform")
			PLATFORM="$(echo $2 | tr [A-Z] [a-z])" # We make user input lowercase, just in case
	esac
	# We shift two time to remove the argument and its value
	shift
	shift
done

# When we have finished parsing the options, we can execute the commands
case "$1" in
	"o" | "orpheus")
		orpheus "${@:2}" # We pass all the array, without the command and everything that's before
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
