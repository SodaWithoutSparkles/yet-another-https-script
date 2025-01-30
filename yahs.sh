#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset
trap 'echo An unexpected error occurred. Exiting.' ERR
VERSION="0.0.1"
DEPENDENCIES=("curl" "dig")

print_ascii_art() {
    echo "--------------------------------- Yet Another HTTPS Script ---------------------------------"
    echo "                                                                                            "
    echo "                                                                                            "
    echo "YYYYYYY       YYYYYYY           AAA               HHHHHHHHH     HHHHHHHHH   SSSSSSSSSSSSSSS "
    echo "Y:::::Y       Y:::::Y          A:::A              H:::::::H     H:::::::H SS:::::::::::::::S"
    echo "Y:::::Y       Y:::::Y         A:::::A             H:::::::H     H:::::::HS:::::SSSSSS::::::S"
    echo "Y::::::Y     Y::::::Y        A:::::::A            HH::::::H     H::::::HHS:::::S     SSSSSSS"
    echo "YYY:::::Y   Y:::::YYY       A:::::::::A             H:::::H     H:::::H  S:::::S            "
    echo "   Y:::::Y Y:::::Y         A:::::A:::::A            H:::::H     H:::::H  S:::::S            "
    echo "    Y:::::Y:::::Y         A:::::A A:::::A           H::::::HHHHH::::::H   S::::SSSS         "
    echo "     Y:::::::::Y         A:::::A   A:::::A          H:::::::::::::::::H    SS::::::SSSSS    "
    echo "      Y:::::::Y         A:::::A     A:::::A         H:::::::::::::::::H      SSS::::::::SS  "
    echo "       Y:::::Y         A:::::AAAAAAAAA:::::A        H::::::HHHHH::::::H         SSSSSS::::S "
    echo "       Y:::::Y        A:::::::::::::::::::::A       H:::::H     H:::::H              S:::::S"
    echo "       Y:::::Y       A:::::AAAAAAAAAAAAA:::::A      H:::::H     H:::::H              S:::::S"
    echo "       Y:::::Y      A:::::A             A:::::A   HH::::::H     H::::::HHSSSSSSS     S:::::S"
    echo "    YYYY:::::YYYY  A:::::A               A:::::A  H:::::::H     H:::::::HS::::::SSSSSS:::::S"
    echo "    Y:::::::::::Y A:::::A                 A:::::A H:::::::H     H:::::::HS:::::::::::::::SS "
    echo "    YYYYYYYYYYYYYAAAAAAA                   AAAAAAAHHHHHHHHH     HHHHHHHHH SSSSSSSSSSSSSSS   "
    echo "                                                                                            "
    echo "                                                                                            "
    echo "--------------------------------- Yet Another HTTPS Script ---------------------------------"
}
print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --domain-name      Set the domain name for the HTTPS server (required)"
    echo "  -b, --backend-url      Set the backend URL to be reverse proxied "
    echo "  -p, --port             Set the port number for the HTTPS server, default is 443"
    echo "  -d, --debug            Enable debug mode"
    echo "      --force            Ignore checks results"
    echo "      --pkgs             Install packages automatically"
    echo "  -v, --version[s]       Show script version"
    echo "  -y, --defaults         Use default settings, but interactively ask for permission to install things"
    echo "  -6, --ipv6             Enable IPv6 support"
    echo "      --no-ipv4          Disable IPv4 support"
    echo "      --no-ipv6          Disable IPv6 support"
    echo "      --no-caddy         Disable caddy installation"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --backend-url localhost:8080 --domain-name example.com --ipv6"
    echo "  $0 -b localhost:8080 -n example.com --debug --defaults --pkgs       # No user interaction"
    echo "  $0 -b localhost:8080 -n example.com -dy --pkgs --force              # Ignore checks as well"

}

# Default values for configuration
DEBUG=0
VERSIONS=0
USE_DEFAULTS=0
BACKEND_URL=""
DOMAIN_NAME=""
ENABLE_IPV4=1
ENABLE_IPV6=0
FORCE=0
INSTALL_PACKAGES=0
CADDY=1
HTTPS_PORT=443

# Global variables
PACKAGE_MGR=""

# Parse options
# _____________________________________________________________________________

parse_options() {
    # Define options
    local OPTS="dvhyb:n:p:6"
    local LONGOPTS="force,debug,versions,version,defaults,backend-url:,domain-name:,ipv6,no-ipv4,no-ipv6,help,dependencies,no-caddy,port:"

    # Parse options
    # test getopt first, exit if not supported
    getopt --test >/dev/null && true
    if [[ $? -ne 4 ]]; then
        echo '`getopt --test` failed in this environment.'
        echo 'Ensure util-linux is installed and up to date.'
        exit 1
    fi
    OPTIONS=$(getopt -o $OPTS --long $LONGOPTS -- "$@")
    if [ $? -ne 0 ]; then
        echo "Failed to parse options." >&2
        exit 1
    fi

    eval set -- "$OPTIONS"

    while true; do
        case "$1" in
        -d | --debug)
            DEBUG=1
            shift
            ;;
        -v | --versions | --version)
            echo "YAHS version: $VERSION"
            exit 0
            ;;
        -h | --help)
            print_usage
            exit 0
            ;;
        -y | --defaults)
            USE_DEFAULTS=1
            shift
            ;;
        -b | --backend-url)
            BACKEND_URL="$2"
            shift 2
            ;;
        -n | --domain-name)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -6 | --ipv6)
            ENABLE_IPV6=1
            shift
            ;;
        --no-ipv4)
            ENABLE_IPV4=0
            shift
            ;;
        --no-ipv6)
            ENABLE_IPV6=0
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --pkgs)
            INSTALL_PACKAGES=1
            shift
            ;;
        --no-caddy)
            CADDY=0
            shift
            ;;
        -p | --port)
            HTTPS_PORT="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
        esac
    done
}

# Call the function to parse options
parse_options "$@"

# _____________________________________________________________________________

# Function to print parameters in a box
print_params_box() {
    echo "Parameters:"
    echo "--------------------------------"
    echo "VERSION     | $VERSION         "
    echo "FORCE       | $FORCE           "
    echo "DEBUG       | $DEBUG           "
    echo "DEFAULTS    | $USE_DEFAULTS    "
    echo "BACKEND_URL | $BACKEND_URL     "
    echo "DOMAIN_NAME | $DOMAIN_NAME     "
    echo "ENABLE_IPV4 | $ENABLE_IPV4     "
    echo "ENABLE_IPV6 | $ENABLE_IPV6     "
    echo "--------------------------------"
}
# detect if system is using apt/yum/dnf/pacman and install dependencies
install_dependencies() {
    install_cmd=""
    case $PACKAGE_MGR in
    "apt")
        install_cmd="sudo apt update && sudo apt install -y ${missing_dependencies[*]}"
        ;;
    "yum" | "dnf")
        install_cmd="sudo $PACKAGE_MGR install -y ${missing_dependencies[*]}"
        ;;
    "pacman")
        install_cmd="sudo pacman -Syu --noconfirm ${missing_dependencies[*]}"
        ;;
    *)
        echo "Error: Unsupported package manager."
        exit 1
        ;;
    esac

    echo "Info: The following command will be executed to install dependencies:"
    echo "    $install_cmd"
    if [ $INSTALL_PACKAGES -eq 0 ]; then
        read -p "Do you want to proceed with the installation? [Y/n]: " user_input
        user_input=${user_input:-Y}
        if [[ "$user_input" =~ ^[Nn]$ ]]; then
            echo "Error: Installation aborted by user."
            exit 1
        fi
    fi
    echo "Info: Installing dependencies using $PACKAGE_MGR..."
    echo "----------------------------------------"
    eval "$install_cmd"
    # check if dependencies are installed successfully by checking the return code
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install dependencies."
        exit 1
    fi
    echo "----------------------------------------"

    echo "Okay: Dependencies installed successfully."

}
# Function to check if required dependencies are installed
check_dependencies() {
    # Check if required commands are available
    local missing_dependencies=()
    for dependency in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dependency" &>/dev/null; then
            echo "Error: $dependency is not installed." >&2
            # add missing dependencies to a list
            missing_dependencies+=("$dependency")
        fi
    done
    # special case for coreutils, util-linux, ncurses-bin, ncurses
    command -v head >/dev/null || missing_dependencies+=("coreutils")
    command -v getopts >/dev/null || missing_dependencies+=("util-linux")
    if ! command -v tput >/dev/null; then
        if [ -f /etc/debian_version ]; then
            missing_dependencies+=("ncurses-bin")
        else
            missing_dependencies+=("ncurses")
        fi
    fi

    echo "Detecting package manager..."
    if command -v apt &>/dev/null; then
        PACKAGE_MGR="apt"
    elif command -v yum &>/dev/null; then
        PACKAGE_MGR="yum"
    elif command -v dnf &>/dev/null; then
        PACKAGE_MGR="dnf"
    elif command -v pacman &>/dev/null; then
        PACKAGE_MGR="pacman"
    else
        echo "Error: Unable to detect package manager."
        exit 1
    fi
    echo "Detected package manager: $PACKAGE_MGR"
    # if there are missing dependencies, prompt users to install them
    if [ ${#missing_dependencies[@]} -ne 0 ]; then
        # print missing dependencies in a line
        echo "Info: Missing dependencies: ${missing_dependencies[*]}" >&2
    else
        echo "Info: All dependencies are installed."
        return
    fi

    # ask users if they want to install missing dependencies
    if [ $INSTALL_PACKAGES -eq 1 ]; then
        echo "Info: Installing missing dependencies..."
    else
        # Avoid using ask_user_yn function to prevent circular dependency
        read -p "Do you want to install the missing dependencies? [Y/n]: " user_input
        user_input=${user_input:-Y}
        if [[ "$user_input" =~ ^[Yy]$ ]]; then
            echo "Info: Installing missing dependencies..."
        else
            echo "Error: Please install the missing dependencies and try again."
            exit 1
        fi
    fi
    install_dependencies

}
# dependencies have to be checked before looking for colors
check_dependencies

# Detect if shell supports colors
# _____________________________________________________________________________
if [ -t 1 ]; then
    ncolors=$(tput colors)
    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        RED=$(tput setaf 1)
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 3)
        BLUE=$(tput setaf 4)
        BOLD=$(tput bold)
        NORMAL=$(tput sgr0)
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        BOLD=""
        NORMAL=""
    fi
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NORMAL=""
fi

# Icons
GREEN_TICK="${GREEN}✔${NORMAL}"
RED_CROSS="${RED}✘${NORMAL}"
INFO_TAG="${BLUE}i${NORMAL}"
WARN_TAG="${YELLOW}!${NORMAL}"
PROG="${BLUE}>${NORMAL}"
# Logging function
logg() {
    local message=$1
    local level=$2
    local color=${3:-$NORMAL}
    local icon=""

    case $level in
    "INFO")
        icon=$INFO_TAG
        ;;
    "SUCCESS")
        icon=$GREEN_TICK
        ;;
    "ERROR")
        icon=$RED_CROSS
        ;;
    "WARN")
        icon=$WARN_TAG
        ;;
    "PROG")
        icon=$PROG
        ;;
    *)
        icon=$INFO_TAG
        ;;
    esac

    echo -e "[${icon}]${color} ${message}${NORMAL}"

    if [ -d /tmp ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >>/tmp/yahs.log
    fi
}
# Function: ask_user_preference
# Description: Prompts the user for input with a default value. If the USE_DEFAULTS
#              variable is set to 1 and the default value is not empty, it will
#              automatically use the default value without prompting the user.
# Parameters:
#   $1 - The prompt message to display to the user.
#   $2 - The default value to use if the user does not provide any input.
#   $3 - A hint message to display to the user.
# Returns: The user's input or the default value if no input is provided.
# Usage:
#   user_choice=$(ask_user_preference "Prompt" "default_value" "hint(default_value)")
ask_user_preference() {
    local prompt=$1
    local default_value=$2
    local hint=${3:-$default_value}
    local user_input=""

    if [ $USE_DEFAULTS -eq 1 ] && [ -n "$default_value" ]; then
        logg "Using default for $prompt: $default_value" "INFO" "$YELLOW"
        echo "$default_value"
        return
    fi

    read -p "$prompt [$hint]: " user_input
    if [ -z "$user_input" ]; then
        user_input="$default_value"
    fi

    echo "$user_input"
}
# special case for user preference where user answers are y/n, reuse the ask_user_preference function
ask_user_yn() {
    local yn_default=$(echo "${2:-y}" | tr '[:upper:]' '[:lower:]')
    if [[ "$yn_default" != "y" && "$yn_default" != "n" ]]; then
        logg "Invalid default value: $yn_default. Must be 'y' or 'n'." "ERROR" "$RED"
        exit 1
    fi
    local prompt_suffix="Y/n"
    if [ "$yn_default" == "n" ]; then
        prompt_suffix="y/N"
    fi
    user_choice=$(ask_user_preference "$1" "$yn_default" "$prompt_suffix")
    echo "$user_choice" | tr '[:upper:]' '[:lower:]'
}
# _____________________________________________________________________________
# Main script helper functions
verify_parameters() {
    if [ $DEBUG -eq 1 ]; then
        logg "Debug mode is enabled." "INFO" "$YELLOW"
        print_params_box
    fi

    if [ $USE_DEFAULTS -eq 1 ]; then
        logg "Accepting default settings" "INFO" "$YELLOW"
    fi
    # detect if no v4 and v6
    if [ $ENABLE_IPV4 -eq 0 ] && [ $ENABLE_IPV6 -eq 0 ]; then
        logg "Both IPv4 and IPv6 are disabled. At least one of them must be enabled." "ERROR" "$RED"
        exit 1
    fi
    # warning for force
    if [ $FORCE -eq 1 ]; then
        logg "Force mode is enabled. Ignoring checks." "WARN" "$YELLOW"
    fi
    if [ -z "$BACKEND_URL" ]; then
        echo "Error: --backend-url is required." >&2
        print_usage
        exit 1
    fi

    if [ -z "$DOMAIN_NAME" ]; then
        logg "Warning: --domain-name is not provided. A random domain name will be generated." "WARN" "$YELLOW"
        DOMAIN_NAME="RANDOM"
        GEN_DOMAIN_NAME=1
    fi

    # Verify backend URL (IPv4:PORT, IPv6:PORT, or localhost:PORT), if CADDY is enabled
    if ! [[ "$BACKEND_URL" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|(\[[0-9a-fA-F:]+\])|localhost):[0-9]+$ ]]; then
        logg "Invalid backend URL: $BACKEND_URL" "ERROR" "$RED"
        if [ $FORCE -eq 0 ]; then
            if [ $CADDY -eq 1 ]; then
                logg "FORCE is enabled. Ignoring checks." "WARN" "$YELLOW"
                logg "Continuing with possibily invalid backend URL." "WARN" "$YELLOW"
            fi
            exit 1
        fi
    fi
    # Verify domain name
    if [ -z "${GEN_DOMAIN_NAME:-}" ]; then
        if ! [[ "$DOMAIN_NAME" =~ ^([a-zA-Z0-9](-*[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
            logg "Invalid domain name: $DOMAIN_NAME" "ERROR" "$RED"
            if [ $FORCE -eq 0 ]; then
                exit 1
            fi
        fi
    fi
    # Verify HTTPS port
    if ! [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] || [ "$HTTPS_PORT" -lt 1 ] || [ "$HTTPS_PORT" -gt 65535 ]; then
        logg "Invalid HTTPS port: $HTTPS_PORT. Port must be a number between 1 and 65535." "ERROR" "$RED"
        if [ $FORCE -eq 0 ]; then
            if [ $CADDY -eq 1 ]; then
                logg "FORCE is enabled. Ignoring checks." "WARN" "$YELLOW"
                logg "Continuing with invalid port." "WARN" "$YELLOW"
            fi
        fi
    fi
    logg "Using domain name: $DOMAIN_NAME" "INFO"
    logg "Parameters verified successfully." "SUCCESS"
}
gen_domain_name() {
    # Generate a password of length 32
    # Using non-standard way to generate random password to avoid pipefail
    logg "Generating a random domain name..." "PROG"
    DDNS_PASSWORD=$(head -c 256 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
    # check if the length of the password is 32, generate a new one if not
    while [ ${#DDNS_PASSWORD} -ne 32 ]; do
        logg "Regenerating password..." "PROG"
        DDNS_PASSWORD=$(head -c 256 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
    done
    logg "Generated password: $DDNS_PASSWORD" "INFO" "$YELLOW"

    response=$(curl -s "https://dyn.addr.tools/?secret=$DDNS_PASSWORD")
    if [[ "$response" =~ ^[a-zA-Z0-9]+\.dyn\.addr\.tools\.?$ ]]; then
        DOMAIN_NAME="${response%.}"
        logg "Generated domain name: $DOMAIN_NAME" "INFO"
    else
        logg "Failed to get domain name from https://dyn.addr.tools. Response: $response" "ERROR" "$RED"
        exit 1
    fi

    if [ $ENABLE_IPV4 -eq 1 ]; then
        logg "Registering domain name for IPv4..." "PROG"
        response_v4=$(curl -s "https://ipv4.dyn.addr.tools/?secret=$DDNS_PASSWORD&ip=self")
        if [ "$response_v4" != "OK" ]; then
            logg "Failed to register IPv4 domain name. Response: $response_v4" "WARN" "$YELLOW"
            logg "Retry with curl -s https://ipv4.dyn.addr.tools/?secret=$DDNS_PASSWORD&ip=self" "INFO"
        fi
    fi

    if [ $ENABLE_IPV6 -eq 1 ]; then
        logg "Registering domain name for IPv6..." "PROG"
        response_v6=$(curl -s "https://ipv6.dyn.addr.tools/?secret=$DDNS_PASSWORD&ip=self")
        if [ "$response_v6" != "OK" ]; then
            logg "Failed to register IPv6 domain name. Response: $response_v6" "WARN" "$YELLOW"
            logg "Retry with curl -s https://ipv6.dyn.addr.tools/?secret=$DDNS_PASSWORD&ip=self" "INFO"
        fi
    fi

    if [ "${response_v4:-}" != "OK" ] && [ "${response_v6:-}" != "OK" ]; then
        logg "Failed to register domain name for both IPv4 and IPv6." "ERROR" "$RED"
        exit 1
    fi
    logg "Domain name registration completed successfully." "SUCCESS"
}
check_domain_resolution() {
    local current_ipv4=""
    local current_ipv6=""
    local resolved_ipv4=""
    local resolved_ipv6=""
    logg "Verifying domain name resolution for $DOMAIN_NAME" "PROG"
    if [ $ENABLE_IPV4 -eq 1 ]; then
        current_ipv4=$(curl -s https://myipv4.addr.tools)
        # Replace newline characters with spaces
        resolved_ipv4=$(dig +short "$DOMAIN_NAME" A | tr '\n' ' ')
        # Remove trailing whitespace using Bash parameter expansion
        resolved_ipv4="${resolved_ipv4%"${resolved_ipv4##*[![:space:]]}"}"
        if [ "$current_ipv4" != "$resolved_ipv4" ]; then
            logg "IPv4 address mismatch: Current IP ($current_ipv4) does not match resolved IP ($resolved_ipv4)" "ERROR" "$RED"
            logg "Confirm you had a public IPv4 address and the domain name is configured properly" "INFO"
            if [ $FORCE -eq 0 ]; then
                exit 1
            fi
        fi
    fi

    if [ $ENABLE_IPV6 -eq 1 ]; then
        current_ipv6=$(curl -s https://myipv6.addr.tools)
        resolved_ipv6=$(dig +short "$DOMAIN_NAME" AAAA | tr '\n' ' ')
        resolved_ipv6="${resolved_ipv6%"${resolved_ipv6##*[![:space:]]}"}"
        if [ "$current_ipv6" != "$resolved_ipv6" ]; then
            logg "IPv6 address mismatch: Current IP ($current_ipv6) does not match resolved IP ($resolved_ipv6)" "ERROR" "$RED"
            logg "Confirm you had a public IPv6 address and the domain name is configured properly" "INFO"
            logg "If you don't have IPv6, disable it using --no-ipv6" "INFO"
            logg "If you have IPv6, check if the DNS records are configured properly" "INFO"
            if [ $FORCE -eq 0 ]; then
                exit 1
            fi
        fi
    fi
    if [ $FORCE -eq 0 ]; then
        logg "Domain name resolution checks passed." "SUCCESS"
    fi
}
# Install the caddy webserver
install_caddy() {
    # Ref: https://caddyserver.com/docs/install
    case $PACKAGE_MGR in
    "apt")
        install_cmd="sudo apt update && sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https && "
        install_cmd+="curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && "
        install_cmd+="curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list && "
        install_cmd+="sudo apt update && sudo apt install -y caddy"
        ;;
    "yum")
        install_cmd="sudo yum -y install yum-plugin-copr && sudo yum -y enable @caddy/caddy && sudo yum -y install caddy"
        ;;
    "dnf")
        install_cmd="sudo dnf -y install 'dnf-command(copr)' && sudo dnf -y copr enable @caddy/caddy && sudo dnf -y install caddy"
        ;;
    "pacman")
        install_cmd="sudo pacman -Syu --noconfirm caddy"
        ;;
    *)
        logg "Unsupported package manager." "ERROR" "$RED"
        exit 1
        ;;
    esac
    logg "The following command will be executed to install caddy:" "INFO"
    echo "    $install_cmd"
    # ask user to confirm the installation
    if [ "$(ask_user_yn "Do you want to proceed with the installation?" "Y")" == "n" ]; then
        logg "Installation aborted by user." "ERROR" "$RED"
        exit 1
    fi
    logg "Installing Caddy web server..." "PROG"
    echo "----------------------------------------"
    eval "$install_cmd"
    # check if dependencies are installed successfully by checking the return code
    if [ $? -ne 0 ]; then
        logg "Failed to install caddy." "ERROR" "$RED"
        exit 1
    fi
    echo "----------------------------------------"
    logg "Caddy installed successfully." "SUCCESS"

}
deploy_caddy_config() {
    # Create a Caddyfile
    logg "Deploying Caddy configuration..." "PROG"
    # generate a random temporary file and echo to it
    TEMP_FILE=$(mktemp)
    if [ "$HTTPS_PORT" -eq 443 ]; then
        echo -e "https://$DOMAIN_NAME {\n    reverse_proxy $BACKEND_URL\n}" >$TEMP_FILE
    else
        echo -e "https://$DOMAIN_NAME:$HTTPS_PORT {\n    reverse_proxy $BACKEND_URL\n}" >$TEMP_FILE
    fi
    logg "The following Caddy configuration will be deployed:" "INFO"
    echo "----------------------------------------"
    cat $TEMP_FILE
    echo "----------------------------------------"
    # Ask user to confirm the deployment
    if [ "$(ask_user_yn "Do you want to deploy the configuration?" "Y")" == "n" ]; then
        logg "Deployment aborted by user." "ERROR" "$RED"
        exit 1
    fi
    # Create a backup of the existing Caddyfile
    if [ -f /etc/caddy/Caddyfile ]; then
        logg "Creating a backup of the existing Caddyfile..." "PROG"
        local dest="/etc/caddy/Caddyfile-$(date +%s).bak"
        eval "sudo cp /etc/caddy/Caddyfile $dest"
        logg "Current CaddyFile backed up to $dest" "SUCCESS"
    fi
    # Move the temporary file to the Caddyfile location
    logg "Deploying Caddy configuration..." "PROG"
    eval "sudo mv $TEMP_FILE /etc/caddy/Caddyfile"
    if [ $? -ne 0 ]; then
        logg "Failed to deploy Caddy configuration." "ERROR" "$RED"
        exit 1
    fi
    logg "Caddy configuration deployed successfully." "SUCCESS"
    # clean up the temporary file if it exists
    if [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
    fi
    # Enable and start caddy service
    logg "Enabling and starting caddy service..." "PROG"
    eval "sudo systemctl enable caddy && sudo systemctl restart caddy"
    if [ $? -ne 0 ]; then
        logg "Failed to enable and start caddy service." "ERROR" "$RED"
        exit 1
    fi
    logg "Caddy service enabled and started successfully." "SUCCESS"
}
# Main script logic
print_ascii_art
verify_parameters

# if GEN_DOMAIN_NAME is set, run the gen_domain_name function
if [ -n "${GEN_DOMAIN_NAME:-}" ]; then
    # Ask user if they want to generate a domain name
    if [ "$(ask_user_yn "Do you want to generate a random domain name?" "Y")"== "n" ]; then
        logg "Please provide a valid domain name using -n. See -h for help." "ERROR" "$RED"
        logg "Exiting..." "INFO"
        exit 0
    fi
    gen_domain_name
fi
# create a function to check if the domain name points to current address
check_domain_resolution

# Check if Caddy is already installed
if command -v caddy &>/dev/null; then
    logg "Caddy is already installed." "INFO"
    logg "Existing configuration are untouched." "SUCCESS" "$GREEN"
    exit 0
else
    if [ $CADDY -eq 1 ] && [ $INSTALL_PACKAGES -eq 1]; then
        install_caddy && deploy_caddy_config
    else
        logg "Caddy installation is disabled by user." "INFO" "$YELLOW"
        exit 0
    fi
fi
