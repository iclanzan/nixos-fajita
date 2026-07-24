{ lib, pkgs, ... }:
{
  services.gnome.gnome-initial-setup.enable = false;
  services.avahi.enable = false;
  services.xserver.enable = false;

  services.xserver.desktopManager.phosh = {
    enable = true;
    group = "users";
    phocConfig.xwayland = "true";
  };

  services.gnome.core-apps.enable = true;

  i18n.inputMethod = {
    type = "ibus";
    ibus.waylandFrontend = true;
  };

  programs.feedbackd.enable = true;

  # Gives Phosh access to GPS data
  services.geoclue2.whitelistedAgents = [ "sm.puri.Phosh" ];

  # Phosh uses wpa_supplicant
  networking.wireless.iwd.enable = false;

  programs.dconf.profiles.user.databases = with lib.gvariant; [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          # Limited space because of notch
          clock-show-date = false;
        };
        "org/gnome/desktop/screensaver" = {
          clock-show-date = true;
        };
        "org/gnome/desktop/session" = {
          idle-delay = mkUint32 60;
        };
        "org/gnome/settings-daemon/peripherals/touchscreen" = {
          orientation-lock = true;
        };
        "org/gnome/settings-daemon/plugins/housekeeping" = {
          donation-reminder-enabled = false;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          ambient-enabled = true;
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-type = "nothing";
        };
        "org/gnome/system/location" = {
          enabled = true;
        };
        "org/gnome/Contacts" = {
          did-initial-setup = true;
        };
        "org/gnome/GWeather" = {
          temperature-unit = "centigrade";
        };
        "org/gnome/GWeather4" = {
          temperature-unit = "centigrade";
        };
        "sm/puri/phosh" = {
          osk-unfold-delay = 0.5;
          app-filter-mode = mkEmptyArray type.string;
        };
        "sm/puri/phosh/plugins" = {
          quick-settings = [
            "wifi-hotspot-quick-setting"
            "mobile-data-quick-setting"
            "caffeine-quick-setting"
            "dark-mode-quick-setting"
          ];
        };
      };
    }
  ];

  # Included in Gnome, but needed by Phosh too
  systemd.packages = with pkgs; [
    xdg-user-dirs # Update user dirs as described in https://freedesktop.org/wiki/Software/xdg-user-dirs/
    xdg-user-dirs-gtk # Used to create the default bookmarks
  ];
  systemd.user.services.user-dirs-update-gtk.wantedBy = [
    "gnome-session@phosh.target"
  ];

  systemd.user.services.evolution-alarm-notify.wantedBy = [
    "gnome-session@phosh.target"
  ];

  environment.systemPackages = with pkgs; [
    phosh-mobile-settings
  ];

  environment.gnome.excludePackages = with pkgs; [
    epiphany
    gnome-connections
    gnome-music
    gnome-software
    gnome-system-monitor
    gnome-tour
    yelp # Gnome help
  ];

}
