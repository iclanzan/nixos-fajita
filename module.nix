{ impermanence, ... }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  persistPath = "/persist";
  user = config.oneplus-fajita.user;
in
{
  imports = [
    impermanence.nixosModules.impermanence
    ./modules/fajita
    ./modules/phosh.nix
  ];

  options.oneplus-fajita = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    user = mkOption {
      type = types.str;
    };
  };

  config = lib.mkIf config.oneplus-fajita.enable {
    nixpkgs.overlays = [ (import ./pkgs) ];

    boot.initrd.unl0kr = {
      enable = true;
      settings = {
        theme = {
          default = "adwaita-dark";
          alternate = "nord-light";
        };
        quirks = {
          fbdev_force_refresh = true;
        };
      };
    };

    zramSwap = {
      enable = true;
      memoryPercent = 100;
    };

    boot.tmp.useTmpfs = false;

    boot.initrd.systemd.services.btrfs-wipe = {
      description = "Wipe root BTRFS filesystem";
      wantedBy = [ "initrd.target" ];
      after = [ "systemd-cryptsetup@crypted.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script =
        let
          tmpdir = "/tmpbtrfs";
        in
        # Need to use `--recursive` because SystemD creates a bunch of subvolumes
        # all on its own when root is BTRFS.
        ''
          mkdir -p ${tmpdir}
          mount -o subvol=/ /dev/mapper/crypted ${tmpdir}
          btrfs subvolume delete --recursive ${tmpdir}/root
          btrfs subvolume create ${tmpdir}/root
          umount ${tmpdir}
        '';
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/nixosboot";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };

    boot.initrd.luks.devices."crypted" = {
      device = "/dev/disk/by-label/nixosluks";
      allowDiscards = true;
    };

    fileSystems."/" = {
      device = "/dev/mapper/crypted";
      fsType = "btrfs";
      options = [
        "subvol=root"
        "noatime"
      ];
    };

    fileSystems."/nix" = {
      device = "/dev/mapper/crypted";
      fsType = "btrfs";
      options = [
        "subvol=nix"
        "compress=zstd"
        "noatime"
      ];
    };

    fileSystems."${persistPath}" = {
      device = "/dev/mapper/crypted";
      fsType = "btrfs";
      options = [
        "subvol=persist"
        "compress=zstd"
      ];
      neededForBoot = true;
    };

    environment.persistence."${persistPath}" = {
      hideMounts = true;
      enableWarnings = false;
      directories = [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/NetworkManager"
        "/etc/NetworkManager/system-connections"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
      ];
      users."${user}" = {
        directories = [
          "Data"
          "Local"

          ".config/chromium"
          ".cache/chromium"

          ".local/share/evolution"
          ".cache/evolution/addressbook"
          ".cache/evolution/calendar"

          ".local/share/flatpak"
          ".var/app"
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      chatty # SMS
      firefox-mobile
      foliate # e-book reader
      gapless # music player
      geary
      gnome-calculator
      gnome-calendar
      gnome-console
      gnome-contacts
      gnome-clocks
      gnome-maps
      gnome-sound-recorder
      gnome-weather
      gnome-console
      passes # stores tickes and passes
      portfolio-filemanager
      powersupply
      resources # system monitor
      shortwave # internet radio
      speedtest
      wl-clipboard
    ];

    nixpkgs.config.permittedInsecurePackages = [
      "olm-3.2.16" # indirect dependency of chatty
    ];

    services.flatpak.enable = true;

    programs.calls.enable = true;

    services.geoclue2.enable = true;
    users.users.geoclue.extraGroups = [ "networkmanager" ];

    environment.etc."machine-info".text = lib.mkDefault ''
      CHASSIS="handset"
    '';

    services.xserver.desktopManager.phosh = {
      user = user;
      phocConfig.outputs.DSI-1.scale = 3;
    };

    users.users."${user}".extraGroups = [
      "dialout"
      "feedbackd"
      "input" # needed for haptics
      "networkmanager"
      "video"
    ];
    users.mutableUsers = false;

    nix.distributedBuilds = true;

    documentation.enable = false;
    documentation.man.enable = false;
    documentation.doc.enable = false;
    documentation.info.enable = false;
    documentation.nixos.enable = false;
  };
}
