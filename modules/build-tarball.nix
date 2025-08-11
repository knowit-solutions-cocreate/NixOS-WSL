{ config
, pkgs
, lib
, ...
}:
with builtins;
with lib; let
  cfg = config.wsl.tarball;

  icon = ../assets/NixOS-WSL.ico;
  iconPath = "/etc/nixos.ico";

  wsl-distribution-conf = pkgs.writeText "wsl-distribution.conf" (
    generators.toINI { } {
      oobe.defaultName = "NixOS";
      shortcut.icon = iconPath;
    }
  );

  defaultConfig = pkgs.writeText "default-configuration.nix" ''
    # Edit this configuration file to define what should be installed on
    # your system. Help is available in the configuration.nix(5) man page, on
    # https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

    # NixOS-WSL specific options are documented on the NixOS-WSL repository:
    # https://github.com/nix-community/NixOS-WSL

    { config, lib, pkgs, ... }:

    {
      imports = [
        # include NixOS-WSL modules
        <nixos-wsl/modules>
      ];

      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        extra-substituters = [
          "https://devenv.cachix.org"
        ];
        extra-trusted-public-keys = [
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        ];
      };
      virtualisation = {
        containers.enable = true;
        docker.enable = true;
      };

      # Add user to dockergroup (simple but insecure)
      users.groups.docker.members = [
          "${config.wsl.defaultUser}"
      ];

      wsl = {
        enable = true;
        vscode-remote.enable = true;
        startMenuLaunchers = true;
      };

      # Add packages from nixpkgs here, search in https://search.nixos.org/ unstable branch
      # for available packages
      environment.systemPackages = with pkgs; [
        vim
        wget
        sops
        lazygit
        lazydocker
        gh
        devenv
        direnv
      ];

      # Enable direnv integration
      programs = {
        git.enable = true;
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        bash.completion.enable = true;
        starship.enable = true;

      };

      # Configure your username here!
      wsl.defaultUser = "${config.wsl.defaultUser}";

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It's perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = "${config.system.nixos.release}"; # Did you read the comment?
    }
  '';
in
{
  options.wsl.tarball = {
    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to system configuration which is copied into the tarball";
    };
  };

  # These options make no sense without the wsl-distro module anyway
  config = mkIf config.wsl.enable {
    system.build.tarballBuilder = pkgs.writeShellApplication {
      name = "nixos-wsl-tarball-builder";

      runtimeInputs = [
        pkgs.coreutils
        pkgs.e2fsprogs
        pkgs.gnutar
        pkgs.nixos-install-tools
        pkgs.pigz
        config.nix.package
      ];

      text = ''
        if ! [ $EUID -eq 0 ]; then
          echo "This script must be run as root!"
          exit 1
        fi

        # Use .wsl extension to support double-click installs on recent versions of Windows
        out=''${1:-nixos.wsl}

        root=$(mktemp -p "''${TMPDIR:-/tmp}" -d nixos-wsl-tarball.XXXXXXXXXX)
        # FIXME: fails in CI for some reason, but we don't really care because it's CI
        trap 'chattr -Rf -i "$root" || true && rm -rf "$root" || true' INT TERM EXIT

        chmod o+rx "$root"

        echo "[NixOS-WSL] Installing..."
        nixos-install \
          --root "$root" \
          --no-root-passwd \
          --system ${config.system.build.toplevel} \
          --substituters ""

        echo "[NixOS-WSL] Adding channel..."
        nixos-enter --root "$root" --command 'HOME=/root nix-channel --add https://github.com/nix-community/NixOS-WSL/archive/refs/heads/main.tar.gz nixos-wsl'

        echo "[NixOS-WSL] Adding wsl-distribution.conf"
        install -Dm644 ${wsl-distribution-conf} "$root/etc/wsl-distribution.conf"
        install -Dm644 ${icon} "$root${iconPath}"

        echo "[NixOS-WSL] Adding default config..."
        ${
          if cfg.configPath == null
          then ''
            install -Dm644 ${defaultConfig} "$root/etc/nixos/configuration.nix"
          ''
          else ''
            mkdir -p "$root/etc/nixos"
            cp -R ${lib.cleanSource cfg.configPath}/. "$root/etc/nixos"
            chmod -R u+w "$root/etc/nixos"
          ''
        }

        echo "[NixOS-WSL] Compressing..."
        tar -C "$root" \
          -c \
          --sort=name \
          --mtime='@1' \
          --owner=0 \
          --group=0 \
          --numeric-owner \
          . \
        | pigz > "$out"
      '';
    };
  };
}
