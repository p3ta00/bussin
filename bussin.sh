#!/bin/bash
# tool_manager.sh - A simple tool manager for downloading/updating binaries and git repositories.
#
# Usage examples:
#   # Add a new tool:
#   ./tool_manager.sh -d linux/enumeration/linpeas https://github.com/peass-ng/PEASS-ng/releases/download/20250301-c97fb02a/linpeas.sh [optional_tool_name]
#
#   # Install (i.e. download/clone) all tools from the configuration file:
#   ./tool_manager.sh -install
#
#   # Update all tools (git pull for repos; re-download for binaries):
#   ./tool_manager.sh -update

set -e

# Determine current working directory and the directory of this script.
cwd=$(pwd)
script_dir=$(dirname "$(readlink -f "$0")")

# Configuration file (kept in the same folder as the script)
config_file="$script_dir/tools_list.conf"
# Create the config file if it doesn't exist.
[ ! -f "$config_file" ] && touch "$config_file"

# --- Functions ---

usage() {
    echo "Usage:"
    echo "  $0 -d <destination_directory> <URL> [tool_name]"
    echo "       Downloads a tool to the specified directory (relative to $cwd) and adds it to the configuration."
    echo "       If the URL ends with .git, it will clone or update the repository."
    echo ""
    echo "  $0 -install"
    echo "       Installs all tools saved in the configuration file, relative to $cwd."
    echo ""
    echo "  $0 -update"
    echo "       Updates all tools saved in the configuration file."
    exit 1
}

# download_latest_release
# If the URL is a GitHub release URL, it extracts owner/repo/asset name, queries the GitHub API for the latest release,
# and downloads the asset into the destination folder.
download_latest_release() {
    local url="$1"
    local dest="$2"
    if [[ "$url" == *"github.com"* && "$url" == *"/releases/download/"* ]]; then
        IFS='/' read -r -a parts <<< "$url"
        owner="${parts[3]}"
        repo="${parts[4]}"
        asset_name="${parts[8]}"
        echo "[*] Fetching latest release for $owner/$repo..."
        api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
        response=$(curl -s "$api_url")
        download_url=$(echo "$response" | grep -oP '"browser_download_url": "\K(.*?)(?=")' | grep "$asset_name")
        if [ -z "$download_url" ]; then
            echo "[!] Could not find asset \"$asset_name\" in the latest release for $owner/$repo."
            exit 1
        fi
        echo "[*] Downloading $asset_name from $download_url"
        mkdir -p "$dest"
        curl -L -o "$dest/$asset_name" "$download_url"
    else
        filename=$(basename "$url")
        echo "[*] Downloading $filename from $url"
        mkdir -p "$dest"
        curl -L -o "$dest/$filename" "$url"
    fi
}

# clone_or_update_git
# Clones the repo if it doesn't exist or pulls the latest changes if it does.
clone_or_update_git() {
    local url="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -d "$dest/.git" ]; then
        echo "[*] Directory $dest exists. Updating repository..."
        cd "$dest" && git pull && cd - > /dev/null
    else
        echo "[*] Cloning repository from $url into $dest..."
        git clone "$url" "$dest"
    fi
}

# add_to_config
# Adds a new tool entry to the configuration file if it doesn't already exist.
# The format is: tool_name|relative_destination|tool_type|URL
add_to_config() {
    local tool_name="$1"
    local rel_dest="$2"
    local tool_type="$3"
    local url="$4"
    if ! grep -q "^${tool_name}|" "$config_file"; then
        echo "${tool_name}|${rel_dest}|${tool_type}|${url}" >> "$config_file"
        echo "[*] Tool '$tool_name' added to configuration."
    else
        echo "[*] Tool '$tool_name' already exists in configuration. Skipping addition."
    fi
}

# --- Main Script Logic ---

if [ "$#" -eq 0 ]; then
    usage
fi

case "$1" in
    -d)
        # Download (and add) mode: expects at least destination and URL.
        if [ "$#" -lt 3 ]; then
            usage
        fi
        # Get relative destination (strip any leading slash)
        destination_relative="${2#/}"
        destination="$cwd/$destination_relative"
        url="$3"
        # Determine tool name (optional 4th argument)
        if [ "$#" -eq 4 ]; then
            tool_name="$4"
        else
            if [[ "$url" == *.git ]]; then
                tool_name=$(basename "$url" .git)
            else
                tool_name=$(basename "$url")
                # Optionally strip common binary extensions
                tool_name="${tool_name%.sh}"
                tool_name="${tool_name%.py}"
            fi
        fi
        # Download or clone based on URL type.
        if [[ "$url" == *.git ]]; then
            clone_or_update_git "$url" "$destination"
            tool_type="git"
        else
            download_latest_release "$url" "$destination"
            tool_type="binary"
        fi
        # Add new tool to configuration.
        add_to_config "$tool_name" "$destination_relative" "$tool_type" "$url"
        ;;
    -install)
        # Install all tools from configuration.
        if [ ! -s "$config_file" ]; then
            echo "[*] No tools in configuration. Use -d to add new tools."
            exit 0
        fi
        while IFS="|" read -r tool_name rel_dest tool_type tool_url; do
            dest="$cwd/$rel_dest"
            echo "=== Installing ${tool_name} ==="
            if [ "$tool_type" == "git" ]; then
                clone_or_update_git "$tool_url" "$dest"
            elif [ "$tool_type" == "binary" ]; then
                download_latest_release "$tool_url" "$dest"
            else
                echo "[!] Unknown tool type for $tool_name"
            fi
            echo ""
        done < "$config_file"
        ;;
    -update)
        # Update all tools from configuration.
        if [ ! -s "$config_file" ]; then
            echo "[*] No tools in configuration. Use -d to add new tools."
            exit 0
        fi
        while IFS="|" read -r tool_name rel_dest tool_type tool_url; do
            dest="$cwd/$rel_dest"
            echo "=== Updating ${tool_name} ==="
            if [ "$tool_type" == "git" ]; then
                if [ -d "$dest/.git" ]; then
                    cd "$dest" && git pull && cd - > /dev/null
                else
                    echo "[*] $tool_name not found locally. Cloning..."
                    clone_or_update_git "$tool_url" "$dest"
                fi
            elif [ "$tool_type" == "binary" ]; then
                download_latest_release "$tool_url" "$dest"
            else
                echo "[!] Unknown tool type for $tool_name"
            fi
            echo ""
        done < "$config_file"
        ;;
    *)
        usage
        ;;
esac

exit 0
