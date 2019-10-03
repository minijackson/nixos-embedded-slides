{ nixpkgs ? import <unstable>, ... }:

let
  pkgs = nixpkgs {
    config = { };
    # https://github.com/NixOS/nixpkgs/blob/master/lib/systems/examples.nix
    crossSystem = {
      config = "armv7l-unknown-linux-gnueabihf";
    };
    #overlays = [ (import ./overlay.nix) ];
  };

  config = { ... }:
  {
    environment.noXlibs = true;
    documentation.enable = false;

    # btrfs-progs fails to build
    services.udisks2.enable = false;

    fonts.fontconfig.enable = false;

    nixpkgs.overlays = with pkgs.lib; singleton (const (super: {
      polkit = super.polkit.override { withGnome = false; };

      # pkcs11 needs opensc which depends on libXt? which fails to build and is X library
      rng-tools = super.rng-tools.override { withPkcs11 = false; };

      nix = super.nix.override { withAWS = false; };
    }));

    fileSystems."/".fsType = "tmpfs";

    boot = {
      loader.grub.enable = false;
      enableContainers = false;
      hardwareScan = false;
    };

    powerManagement.enable = false;
  };

in
  pkgs.nixos config
