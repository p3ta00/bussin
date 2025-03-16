Bussin.sh

Bussin.sh is a Bash script for Linux (tested on Kali) that automates the download, installation, and updating of various tools. Whether the tool is a standalone binary (downloaded from a GitHub release) or a Git repository, this script makes it easy to manage your tools with a single command.
Features

    Download Tools:
    Easily download a binary from a GitHub release or clone a Git repository to a specified relative directory.

    Configuration Management:
    Every time you add a tool using the -d flag, the tool’s details are stored in a configuration file (tools_list.conf) located in the same directory as Bussin.sh.

    Install & Update:
    Run the script with -install to install all tools listed in the configuration file, or with -update to update all tools (using git pull for repositories or re-downloading binaries).

    Relative Directory Storage:
    All destination paths are interpreted relative to the directory where you run the script, ensuring consistency regardless of your absolute path.

Installation

    Clone the Repository:

git clone https://github.com/yourusername/bussin.git
cd bussin

Make the Script Executable:

    chmod +x bussin.sh

Usage
Add a New Tool

Use the -d flag to download a new tool and add it to the configuration.

./bussin.sh -d <destination_directory> <URL> [optional_tool_name]

    destination_directory: A path relative to your current working directory (e.g., linux/enumeration/linpeas).
    URL:
        For binaries, use the URL to the GitHub release asset.
        For Git repositories, use the repository URL (ending in .git).
    optional_tool_name: (Optional) Specify a name for the tool; if omitted, the script derives it from the URL.

Example:

Download a binary tool:

./bussin.sh -d linux/enumeration/linpeas https://github.com/peass-ng/PEASS-ng/releases/download/20250301-c97fb02a/linpeas.sh

Download a Git repository (e.g., pypykatz):

./bussin.sh -d linux/enumeration/pypykatz https://github.com/skelsec/pypykatz.git

After running the above commands, the tool details are saved in tools_list.conf in the same directory as Bussin.sh.
Install All Tools

Install all tools that are stored in the configuration file.

./bussin.sh -install

Update All Tools

Update all tools listed in the configuration file. For Git repositories, the script runs git pull; for binaries, it re-downloads the latest release asset.

./bussin.sh -update

Configuration File

Bussin.sh uses a configuration file named tools_list.conf (located in the same directory as the script) to store the tools you add. Each line in this file follows the format:

tool_name|relative_destination|tool_type|URL

    tool_name: The name of the tool.
    relative_destination: The destination path (relative to your working directory).
    tool_type: Either binary or git.
    URL: The download or repository URL.

You can manually edit this file if needed, but it's recommended to use the -d flag to add tools automatically.
Contributing

Contributions are welcome! Please feel free to open issues or submit pull requests to enhance the script or documentation.
License

Distributed under the MIT License. See LICENSE for more information.
