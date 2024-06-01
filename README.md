# BorgBackup Client Container

This repository contains a Nix Flake that builds a Docker container for BorgBackup. The container is configured to perform backups and pruning of backup archives, using the powerful and flexible BorgBackup tool.

## Description

The project creates a Docker image that runs a script to backup specified directories, prune old backups, and handle compression and exclusion of certain files and directories. The image is built using Nix, leveraging `dockerTools.buildImage` for creating the Docker image and `writeShellScriptBin` for the entry point script.

## Usage

### Prerequisites

- [Nix](https://nixos.org/download.html) installed on your system.
- Docker installed and running.

### Building the Image

To build the Docker image, run:

```bash
nix build .#image
```

This will produce a Docker image named `ghcr.io/jobs62/borg-container`.

### Running the Container

Before running the container, ensure you have the necessary environment variables set for BorgBackup. These typically include:

- `BORG_REPO`: The Borg repository location.
- `BORG_PASSPHRASE`: The passphrase for the Borg repository.
- `BORG_TARGET_NAME`: The name to use for the backup archive.
- `BORG_TARGET_DIR`: The directory to backup.

Run the container with:

```bash
docker run -e BORG_REPO -e BORG_PASSPHRASE -e BORG_TARGET_NAME -e BORG_TARGET_DIR ghcr.io/jobs62/borg-container
```

### Backup and Pruning

The entry point script in the container performs the following steps:

1. Starts the backup process, using the specified target directory and creating an archive named after the machine and current date.
2. Prunes old backups to keep 7 daily, 4 weekly, and 6 monthly archives.
3. Outputs the status of the backup and prune operations.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you have suggestions or improvements.

## License

This project is licensed under the MIT License.

## Acknowledgements

- [BorgBackup](https://www.borgbackup.org/) for the robust backup tool.
- [NixOS](https://nixos.org/) and [Nixpkgs](https://github.com/NixOS/nixpkgs) for the package manager and packages.

---

Feel free to modify this README.md to better suit your project's specific details and preferences.