#!/bin/bash
# bussin.sh - Enhanced tool manager for downloading binaries, cloning Git repos,
# installing APT packages, and more on Linux (tested on Kali)
#
# Features:
#   - Enhanced Logging & Verbose Mode (-v)
#   - Dependency Checks (curl, git, apt)
#   - Error Handling & Retries (using curl --retry)
#   - Parallel Processing (--parallel for install/update)
#   - Tool Removal (-remove) & Listing (-list)
#   - Checksum Verification (optional, stub)
#   - Self-Update (-selfupdate)
#   - Interactive Mode (-i)
#   - Configuration Backup (-backup) and Restore (-restore)
#   - Stores configuration in $HOME/.config/bussin
#   - Supports a default installation directory; if not configured, prompts you
#
# Version: 1.1.0

set -e

# Global variables
VERBOSE=0
PARALLEL=0
VERSION="1.1.0"

# Setup configuration folder and files in $HOME/.config/bussin
config_folder="$HOME/.config/bussin"
[ ! -d "$config_folder" ] && mkdir -p "$config_folder"
config_file="$config_folder/tools_list.conf"
[ ! -f "$config_file" ] && touch "$config_file"
log_file="$config_folder/bussin.log"
settings_file="$config_folder/settings.conf"
[ ! -f "$settings_file" ] && touch "$settings_file"

# Logging: prints to stdout if verbose is enabled and appends to a log file.
log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[*] $1"
    fi
    echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" >> "$log_file"
}

# Check that required commands are available.
check_dependencies() {
    for cmd in curl git apt; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "[!] Dependency '$cmd' not found. Please install it."
            exit 1
        fi
    done
}

# Retrieve the default installation directory from settings.conf.
# If not set, prompt the user and save it.
get_default_install_dir() {
    local default_dir
    default_dir=$(grep "^DEFAULT_INSTALL_DIR=" "$settings_file" | cut -d'=' -f2-)
    if [ -z "$default_dir" ]; then
        echo "No default installation directory configured."
        read -p "Enter default installation directory (absolute path): " default_dir
        echo "DEFAULT_INSTALL_DIR=$default_dir" >> "$settings_file"
    fi
    echo "$default_dir"
}

DEFAULT_INSTALL_DIR=$(get_default_install_dir)

# Print usage information.
usage() {
    cat <<EOF
Usage: $0 [options]
Options:
  -d [dest_dir] <URL> [tool_name]
       Add a new binary or Git tool.
       If dest_dir is omitted, the default installation directory ($DEFAULT_INSTALL_DIR) is used.
  -apt <package_name> [tool_name]
       Add a new APT package.
  -install
       Install all tools from configuration.
  -update
       Update all non-APT tools.
  -remove <tool_name>
       Remove a tool from configuration and system.
  -list
       List all managed tools.
  -selfupdate
       Update Bussin.sh itself.
  -backup
       Backup the configuration file.
  -restore <backup_file>
       Restore the configuration file from backup.
  -i
       Interactive mode to add a tool.
  -v
       Enable verbose logging.
  --parallel
       Enable parallel processing for install/update.
  -h, --help
       Show this help message.
EOF
    exit 1
}

# Download a binary release asset (using GitHub API if applicable).
download_latest_release() {
    local url="$1"
    local dest="$2"
    if [[ "$url" == *"github.com"* && "$url" == *"/releases/download/"* ]]; then
        IFS='/' read -r -a parts <<< "$url"
        local owner="${parts[3]}"
        local repo="${parts[4]}"
        local asset_name="${parts[8]}"
        log "Fetching latest release for $owner/$repo..."
        local api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
        local response
        response=$(curl --retry 3 -s "$api_url")
        local download_url
        download_url=$(echo "$response" | grep -oP '"browser_download_url": "\K(.*?)(?=")' | grep "$asset_name")
        if [ -z "$download_url" ]; then
            echo "[!] Could not find asset \"$asset_name\" in the latest release for $owner/$repo."
            exit 1
        fi
        log "Downloading $asset_name from $download_url"
        mkdir -p "$dest"
        curl --retry 3 -L -o "$dest/$asset_name" "$download_url"
    else
        local filename
        filename=$(basename "$url")
        log "Downloading $filename from $url"
        mkdir -p "$dest"
        curl --retry 3 -L -o "$dest/$filename" "$url"
    fi
}

# Clone or update a Git repository.
clone_or_update_git() {
    local url="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -d "$dest/.git" ]; then
        log "Updating repository in $dest..."
        (cd "$dest" && git pull)
    else
        log "Cloning repository from $url into $dest..."
        git clone "$url" "$dest"
    fi
}

# Install an APT package.
install_apt_package() {
    local pkg="$1"
    log "Installing APT package: $pkg"
    sudo apt install -y "$pkg"
}

# Add an entry to the configuration file.
# Format: tool_name|relative_dest|tool_type|URL_or_pkg|checksum (optional)
add_to_config() {
    local tool_name="$1"
    local rel_dest="$2"
    local tool_type="$3"
    local url_or_pkg="$4"
    local checksum="${5:-}"
    if ! grep -q "^${tool_name}|" "$config_file"; then
        echo "${tool_name}|${rel_dest}|${tool_type}|${url_or_pkg}|${checksum}" >> "$config_file"
        log "Tool '$tool_name' added to configuration."
    else
        log "Tool '$tool_name' already exists in configuration. Skipping addition."
    fi
}

# Remove a tool from configuration and optionally from the system.
remove_tool() {
    local tool_name="$1"
    if grep -q "^${tool_name}|" "$config_file"; then
        local line
        line=$(grep "^${tool_name}|" "$config_file")
        IFS="|" read -r name rel_dest tool_type url_or_pkg checksum <<< "$line"
        log "Removing tool '$tool_name' of type '$tool_type'..."
        grep -v "^${tool_name}|" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        if [ "$tool_type" != "apt" ]; then
            local target="$DEFAULT_INSTALL_DIR/$rel_dest"
            if [ -d "$target" ]; then
                rm -rf "$target"
                log "Removed directory $target."
            fi
        fi
        echo "[*] Tool '$tool_name' removed."
    else
        echo "[*] Tool '$tool_name' not found in configuration."
    fi
}

# List all managed tools.
list_tools() {
    if [ ! -s "$config_file" ]; then
        echo "No tools in configuration."
        exit 0
    fi
    echo "Managed Tools:"
    while IFS="|" read -r tool_name rel_dest tool_type url_or_pkg checksum; do
        echo "Name: $tool_name | Type: $tool_type | Dest: $rel_dest | URL/Package: $url_or_pkg"
    done < "$config_file"
}

# Self-update Bussin.sh from a predefined URL.
self_update() {
    local update_url="https://raw.githubusercontent.com/yourusername/bussin/master/bussin.sh"
    log "Updating Bussin.sh from $update_url..."
    curl --retry 3 -L -o "$config_folder/bussin.sh.new" "$update_url"
    if [ -s "$config_folder/bussin.sh.new" ]; then
        mv "$config_folder/bussin.sh.new" "$script_dir/bussin.sh"
        chmod +x "$script_dir/bussin.sh"
        echo "[*] Bussin.sh updated successfully."
    else
        echo "[!] Self-update failed. Please check the update URL."
    fi
}

# Interactive mode to add a tool.
interactive_add() {
    echo "Interactive Tool Addition:"
    read -p "Enter tool type (binary/git/apt): " tool_type
    if [ "$tool_type" != "apt" ]; then
        read -p "Enter destination (relative path, leave empty for default): " rel_dest
        if [ -z "$rel_dest" ]; then
            rel_dest="."
        fi
    else
        rel_dest="apt"
    fi
    read -p "Enter URL or package name: " url_or_pkg
    read -p "Enter tool name (leave empty to auto-derive): " tool_name
    read -p "Enter checksum (optional, leave empty if none): " checksum
    if [ -z "$tool_name" ]; then
        if [ "$tool_type" = "git" ]; then
            tool_name=$(basename "$url_or_pkg" .git)
        else
            tool_name=$(basename "$url_or_pkg")
            tool_name="${tool_name%.sh}"
            tool_name="${tool_name%.py}"
        fi
    fi
    case "$tool_type" in
        apt)
            install_apt_package "$url_or_pkg"
            ;;
        git)
            local dest="$DEFAULT_INSTALL_DIR/$rel_dest"
            clone_or_update_git "$url_or_pkg" "$dest"
            ;;
        binary)
            local dest="$DEFAULT_INSTALL_DIR/$rel_dest"
            download_latest_release "$url_or_pkg" "$dest"
            if [ -n "$checksum" ]; then
                log "Checksum verification not implemented."
            fi
            ;;
        *)
            echo "[!] Unknown tool type."
            exit 1
            ;;
    esac
    add_to_config "$tool_name" "$rel_dest" "$tool_type" "$url_or_pkg" "$checksum"
}

# Backup the configuration file.
backup_config() {
    local backup_file="$config_folder/tools_list.conf.backup_$(date +%Y%m%d%H%M%S)"
    cp "$config_file" "$backup_file"
    echo "[*] Configuration backed up to $backup_file"
}

# Restore the configuration file from a backup.
restore_config() {
    local backup_file="$1"
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$config_file"
        echo "[*] Configuration restored from $backup_file"
    else
        echo "[!] Backup file not found: $backup_file"
    fi
}

# Install all tools (with optional parallel processing).
install_all_tools() {
    if [ ! -s "$config_file" ]; then
        echo "[*] No tools in configuration. Use -d, -apt, or -i to add new tools."
        exit 0
    fi
    while IFS="|" read -r tool_name rel_dest tool_type url_or_pkg checksum; do
        (
        log "Installing $tool_name..."
        case "$tool_type" in
            git)
                local dest="$DEFAULT_INSTALL_DIR/$rel_dest"
                clone_or_update_git "$url_or_pkg" "$dest"
                ;;
            binary)
                local dest="$DEFAULT_INSTALL_DIR/$rel_dest"
                download_latest_release "$url_or_pkg" "$dest"
                ;;
            apt)
                install_apt_package "$url_or_pkg"
                ;;
            *)
                echo "[!] Unknown tool type for $tool_name"
                ;;
        esac
        ) &
        if [ "$PARALLEL" -eq 0 ]; then
            wait
        fi
    done < "$config_file"
    wait
}

# Update all non-APT tools (with optional parallel processing).
update_all_tools() {
    if [ ! -s "$config_file" ]; then
        echo "[*] No tools in configuration. Use -d, -apt, or -i to add new tools."
        exit 0
    fi
    while IFS="|" read -r tool_name rel_dest tool_type url_or_pkg checksum; do
        (
        log "Updating $tool_name..."
        case "$tool_type" in
            git)
                local dest="$DEFAULT_INSTALL_DIR/$rel_dest"
                if [ -d "$dest/.git" ]; then
                    (cd "$dest" && git pull)
                else
                    clone_or_update_git "$url_or_pkg" "$dest"
                fi
                ;;
            binary)
                local dest="$DEFAULT_INSTALL_DIR/$rel_dest"
                download_latest_release "$url_or_pkg" "$dest"
                ;;
            apt)
                echo "[*] Skipping update for APT package '$tool_name'."
                ;;
            *)
                echo "[!] Unknown tool type for $tool_name"
                ;;
        esac
        ) &
        if [ "$PARALLEL" -eq 0 ]; then
            wait
        fi
    done < "$config_file"
    wait
}

# Main logic
check_dependencies

if [ "$#" -eq 0 ]; then
    usage
fi

# Parse command-line arguments.
while [ "$#" -gt 0 ]; do
    case "$1" in
        -d)
            shift
            # Determine if the next argument is a URL (starts with http) or a destination directory.
            if [[ "$1" =~ ^https?:// ]]; then
                dest_dir="."
                url="$1"
                shift
            else
                dest_dir="$1"
                dest_dir="${dest_dir#/}"  # remove any leading slash
                shift
                url="$1"
                shift
            fi
            if [ "$#" -ge 1 ] && [[ "$1" != -* ]]; then
                tool_name="$1"
                shift
            else
                if [[ "$url" == *.git ]]; then
                    tool_name=$(basename "$url" .git)
                else
                    tool_name=$(basename "$url")
                    tool_name="${tool_name%.sh}"
                    tool_name="${tool_name%.py}"
                fi
            fi
            destination="$DEFAULT_INSTALL_DIR/$dest_dir"
            if [[ "$url" == *.git ]]; then
                clone_or_update_git "$url" "$destination"
                tool_type="git"
            else
                download_latest_release "$url" "$destination"
                tool_type="binary"
            fi
            add_to_config "$tool_name" "$dest_dir" "$tool_type" "$url"
            ;;
        -apt)
            shift
            if [ "$#" -lt 1 ]; then usage; fi
            pkg="$1"
            shift
            if [ "$#" -ge 1 ] && [[ "$1" != -* ]]; then
                tool_name="$1"
                shift
            else
                tool_name="$pkg"
            fi
            install_apt_package "$pkg"
            add_to_config "$tool_name" "apt" "apt" "$pkg"
            ;;
        -install)
            shift
            install_all_tools
            ;;
        -update)
            shift
            update_all_tools
            ;;
        -remove)
            shift
            if [ "$#" -lt 1 ]; then usage; fi
            remove_tool "$1"
            shift
            ;;
        -list)
            shift
            list_tools
            ;;
        -selfupdate)
            shift
            self_update
            ;;
        -backup)
            shift
            backup_config
            ;;
        -restore)
            shift
            if [ "$#" -lt 1 ]; then usage; fi
            restore_config "$1"
            shift
            ;;
        -i)
            shift
            interactive_add
            ;;
        -v)
            VERBOSE=1
            shift
            ;;
        --parallel)
            PARALLEL=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

exit 0
