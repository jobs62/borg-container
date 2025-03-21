{
  description = "BorgBackup Client Container";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (
              final: prev: {
                openssh = prev.openssh.overrideAttrs (oldAttrs: {
                  patches =
                    (oldAttrs.patches or [])
                    ++ [
                      ./ssh.patch
                    ];
                });
              }
            )
          ];
        };

        borg-restore =
          pkgs.writeShellScriptBin "borg-restore"
          ''
            # some helpers and error handling:
            info() { printf "\n%s %s\n\n" "$( ${pkgs.coreutils}/bin/date )" "$*" >&2; }
            trap 'echo $( ${pkgs.coreutils}/bin/date ) Restore interrupted >&2; exit 2' INT TERM

            info "Starting restore"

            ${pkgs.borgbackup}/bin/borg extract \
                --list                          \
                ::"''${BORG_TARGET_NAME}"

            global_exit=$?

            if [ ''${global_exit} -eq 0 ]; then
                info "Restore finished successfully"
                exit 0
            elif [ ''${global_exit} -eq 1 ]; then
                info "Restore finished with warnings"
                exit 0
            else
                info "Restore finished with errors"
                exit 1
            fi
          '';

        borg-task =
          pkgs.writeShellScriptBin "borg-entrypoint"
          ''
            # some helpers and error handling:
            info() { printf "\n%s %s\n\n" "$( ${pkgs.coreutils}/bin/date )" "$*" >&2; }
            trap 'echo $( ${pkgs.coreutils}/bin/date ) Backup interrupted >&2; exit 2' INT TERM

            info "Starting backup"

            # Backup the most important directories into an archive named after
            # the machine this script is currently running on:
            ${pkgs.borgbackup}/bin/borg create  \
                --verbose                       \
                --filter AME                    \
                --list                          \
                --stats                         \
                --show-rc                       \
                --compression lz4               \
                --exclude-caches                \
                --exclude 'home/*/.cache/*'     \
                --exclude 'var/tmp/*'           \
                --exclude-if-present '.nobackup' \
                --exclude-if-present '.nobackups' \
                ::"''${BORG_TARGET_NAME}-{now}"   \
                ''${BORG_TARGET_DIR}

            backup_exit=$?

            info "Pruning repository"

            # Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
            # archives of THIS machine. The '{hostname}-' prefix is very important to
            # limit prune's operation to this machine's archives and not apply to
            # other machines' archives also:

            ${pkgs.borgbackup}/bin/borg prune     \
                --list                            \
                --prefix "''${BORG_TARGET_NAME}-" \
                --show-rc                         \
                --keep-daily    7                 \
                --keep-weekly   4                 \
                --keep-monthly  6

            prune_exit=$?

            # use highest exit code as global exit code
            global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

            if [ ''${global_exit} -eq 0 ]; then
                info "Backup, Prune, and Compact finished successfully"
                exit 0
            elif [ ''${global_exit} -eq 1 ]; then
                info "Backup, Prune, and/or Compact finished with warnings"
                exit 0
            else
                info "Backup, Prune, and/or Compact finished with errors"
                exit 1
            fi
          '';

        borg-image = pkgs.dockerTools.buildImage {
          name = "ghcr.io/jobs62/borg-container";
          config = {
            Cmd = ["${borg-task}/bin/borg-entrypoint"];
          };
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [pkgs.fakeNss pkgs.openssh borg-restore];
            pathsToLink = ["/bin" "/etc"];
          };
        };
      in {
        packages = {
          default = borg-task;
          image = borg-image;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = borg-task;
        };
      }
    );
}
