# Bussin.sh

![[DALL·E 2025-03-16 14.53.25 - A vibrant, funny, and meme-inspired logo that features the word 'Bussin' in a playful, exaggerated bubble font. The design should have a retro 90s aes.webp]]

**Bussin.sh** is an enhanced Bash script for Linux (tested on Kali) that automates the download, installation, update, and management of various tools. It supports standalone binaries (downloaded from GitHub releases), Git repositories, and APT packages. All configuration files and settings are stored in a dedicated folder (`$HOME/.config/bussin`), allowing Bussin.sh to be run from any directory.

You can also run the install script as   ./install.sh if you want to be able to execute bussin and have the installation script set up your config files.
## Features

- **Download Tools:**  
  Download a binary from a GitHub release (automatically fetching the latest asset) or clone a Git repository into a specified relative directory.

- **APT Package Support:**  
  Install APT packages via the system package manager (APT). These packages are managed by apt and are exempt from Bussin.sh’s update process.

- **Default Installation Directory:**  
  The default installation directory is configured via a settings file (`$HOME/.config/bussin/settings.conf`). If not set, Bussin.sh will prompt you for an absolute path. All tool installation paths are relative to this default directory.

- **Enhanced Logging & Verbose Mode:**  
  Enable verbose output with the `-v` flag. All log messages are saved to `$HOME/.config/bussin/bussin.log`.

- **Dependency Checks:**  
  Bussin.sh verifies that essential tools (curl, git, apt) are installed before proceeding.

- **Error Handling & Retries:**  
  Uses curl’s built-in retry mechanism (`--retry 3`) for robust network operations.

- **Parallel Processing:**  
  Use the `--parallel` flag with install or update operations to run them concurrently.

- **Tool Removal & Listing:**  
  Easily remove a tool with the `-remove` flag or list all managed tools with the `-list` flag.

- **Checksum Verification (Stub):**  
  Optionally supply a checksum when adding a tool (for future implementation).

- **Self-Update Feature:**  
  Update Bussin.sh itself from a predefined remote source using the `-selfupdate` flag.

- **Interactive Mode:**  
  Use the `-i` flag to be guided through adding a new tool interactively.

- **Configuration Backup & Restore:**  
  Backup the configuration with `-backup` and restore it using `-restore <backup_file>`.

## Installation

 **Clone the Repository:**

```bash
git clone https://github.com/yourusername/bussin.git cd bussin

```

**Make Bussin.sh Executable:**

```bash
chmod +x bussin.sh
```

## Configuration

Bussin.sh stores its configuration in the folder:  
`$HOME/.config/bussin`

This folder contains:

**tools_list.conf** – A list of managed tools. Each entry has the format:

```bash
tool_name|relative_destination|tool_type|URL_or_package|checksum
```

 **settings.conf** – Contains settings such as the default installation directory (e.g., `DEFAULT_INSTALL_DIR=/home/username/tools`). If this setting isn’t configured, Bussin.sh will prompt for it on first use.
 **bussin.log** – Log file for verbose output.

## Usage

Bussin.sh supports multiple commands and modes. Here are some examples:

### Add a New Tool

#### Binary or Git Tool

Add a tool by specifying a destination (relative to your current directory) and a URL. An optional tool name can be provided.

```bash
bash./bussin.sh -d linux/enumeration/linpeas https://github.com/peass-ng/PEASS-ng/releases/download/20250301-c97fb02a/linpeas.sh
```

Or for a Git repository (e.g., pypykatz):

```bash
bash./bussin.sh -d linux/enumeration/pypykatz https://github.com/skelsec/pypykatz.git
```

#### APT Package

Add an APT package (which will be installed via apt):

```bash
bash./bussin.sh -apt nmap
```

### Interactive Mode

Run interactive mode to add a tool without needing to specify all parameters on the command line:

### Install All Tools

Install (or re-install) all tools listed in the configuration file:

*Use the **\--parallel** flag to install tools concurrently:*

```bash
bash./bussin.sh -install --parallel
```

### Update All Tools

Update all non-APT tools (Git and binary downloads):

*Or update in parallel:*

```bash
bash./bussin.sh -update --parallel
```

### Remove a Tool

Remove a tool from the configuration (and optionally its installed files):

```bash
bash./bussin.sh -remove linpeas
```

### List Managed Tools

Display a list of all tools currently managed by Bussin.sh:

### Self-Update

Update Bussin.sh itself from a predefined remote source:

```bash
bash./bussin.sh -selfupdate
```

### Backup & Restore Configuration

Backup your configuration file:

Restore your configuration from a backup file:

```bash
bash./bussin.sh -restore tools_list.conf.backup_YYYYMMDDHHMMSS
```

### Enable Verbose Logging

Add the **\-v** flag to see detailed log output:

```bash
bash./bussin.sh -d linux/enumeration/linpeas https://github.com/peass-ng/PEASS-ng/releases/download/20250301-c97fb02a/linpeas.sh -v
```

## Configuration File

Bussin.sh stores tool details in a configuration file named `tools_list.conf` (located in the same directory as the script). Each line follows this format:

```
tool_name|relative_destination|tool_type|URL_or_package|checksum
```

- **tool\_name:** A unique name for the tool.
- **relative\_destination:** The destination path (relative to your current directory) or `"apt"` for APT packages.
- **tool\_type:** Either `binary`, `git`, or `apt`.
- **URL\_or\_package:** The download URL or APT package name.
- **checksum:** An optional checksum (currently a stub).

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to improve Bussin.sh. Future ideas include full checksum verification, enhanced error handling, and further self-update features.

## License

Distributed under the MIT License. See [LICENSE](https://chatgpt.com/c/LICENSE) for more information.

```
yaml
---

These two files (the updated **bussin.sh** script and the **README.md**) should give you a robust starting point. Feel free to adjust paths, URLs (especially in the self-update section), and further customize features to suit your needs.
```