#!/usr/bin/env bash
#
# install.sh - Installs bussin.sh to /usr/local/bin/bussin, sets up config files,
# and installs Bash completion.
#
# Usage:
#   1. Make install.sh executable: chmod +x install.sh
#   2. Run it with sudo: sudo ./install.sh [path/to/bussin.sh]
#
# If no path is provided, it assumes bussin.sh is in the current directory.

set -e

# Use SUDO_USER's home directory if running with sudo; otherwise use $HOME.
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(eval echo "~$SUDO_USER")
else
  USER_HOME="$HOME"
fi

# 1. Determine path to bussin.sh
if [ -z "$1" ]; then
  SCRIPT_PATH="$(pwd)/bussin.sh"
else
  SCRIPT_PATH="$1"
fi

# 2. Check if bussin.sh exists
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "[!] Could not find bussin.sh at: $SCRIPT_PATH"
  echo "    Please specify the correct path to bussin.sh."
  exit 1
fi

# 3. Create config directory in the user’s home
CONFIG_DIR="$USER_HOME/.config/bussin"
mkdir -p "$CONFIG_DIR"

# 4. Create tools_list.conf and settings.conf if they don't exist
TOOLS_LIST="$CONFIG_DIR/tools_list.conf"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

touch "$TOOLS_LIST"

# If settings.conf is empty or missing DEFAULT_INSTALL_DIR, prompt for it.
if [ ! -s "$SETTINGS_FILE" ] || ! grep -q "^DEFAULT_INSTALL_DIR=" "$SETTINGS_FILE"; then
  echo "No default installation directory is currently set."
  read -rp "Enter default installation directory (absolute path): " DEFAULT_DIR
  echo "DEFAULT_INSTALL_DIR=$DEFAULT_DIR" >> "$SETTINGS_FILE"
  echo "[*] Saved default installation directory to $SETTINGS_FILE"
fi

# 5. Copy bussin.sh to /usr/local/bin/bussin
echo "[*] Installing bussin.sh to /usr/local/bin/bussin..."
sudo cp "$SCRIPT_PATH" /usr/local/bin/bussin
sudo chmod +x /usr/local/bin/bussin

# 6. Create Bash completion script and install it
echo "[*] Installing Bash completion for bussin..."
BUSSIN_COMPLETION=$(cat << 'EOF'
#!/bin/bash
# Bash completion for bussin command

_bussin_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="-d -apt -install -update -remove -list -selfupdate -backup -restore -i -v --parallel -h --help"
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -F _bussin_completions bussin
EOF
)
# Write the completion script to /etc/bash_completion.d/bussin using sudo
echo "$BUSSIN_COMPLETION" | sudo tee /etc/bash_completion.d/bussin > /dev/null
sudo chmod +x /etc/bash_completion.d/bussin

echo "[*] Installation complete!"
echo "You can now run 'bussin' from anywhere."
echo "Bash completion installed. Reload your shell or run: source /etc/bash_completion.d/bussin"
