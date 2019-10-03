# This one is much better than the first
#
# TODO: get `nix build -f cross-build-2.nix vm` to work

{ nixos ? import <unstable/nixos>, ... }:

let
  # https://github.com/NixOS/nixpkgs/blob/master/lib/systems/examples.nix
  target = "armv7l-unknown-linux-gnueabihf";

  configuration = { lib, ... }:
  {
    nixpkgs.crossSystem = lib.systems.elaborate { config = target; };
    nixpkgs.overlays = with lib; singleton (const (super: {
      polkit = super.polkit.override { withGnome = false; };

      # pkcs11 needs opensc which depends on libXt? which fails to build and is X library
      rng-tools = super.rng-tools.override { withPkcs11 = false; };

      nix = super.nix.override { withAWS = false; };

      gobject-introspection = super.callPackage /tmp/gobject-introspection.nix { inherit (darwin) cctools; };
    }));


    environment.noXlibs = true;
    documentation.enable = false;

    # btrfs-progs fails to build
    services.udisks2.enable = false;

    fonts.fontconfig.enable = false;

    fileSystems."/".fsType = "tmpfs";

    boot = {
      loader.grub.enable = false;
      enableContainers = false;
      hardwareScan = false;
    };

    powerManagement.enable = false;
  };

in
  nixos { inherit configuration; }
