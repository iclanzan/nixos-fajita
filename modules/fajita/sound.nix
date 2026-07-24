{ pkgs, ... }:
let
  ucm-env = "/run/current-system/sw/share/alsa/ucm2";
  sdm845-alsa-ucm =
    pkgs.runCommand "sdm845-alsa-ucm"
      {
        src = pkgs.fetchFromGitLab {
          name = "sdm845-alsa-ucm";
          owner = "sdm845-mainline";
          repo = "alsa-ucm-conf";
          rev = "1b8d290e5aa2ca16b7f2fa8d74910ad19ef88b3a";
          sha256 = "sha256-Kg4vxDrli/ffNeUwDBL5GfdJsbwFRPAUieQEsjVKADw=";
        };
        postPatch = "";
      }
      ''
        mkdir -p $out/share
        ln -s $src $out/share/alsa
      '';
in
{
  services.pipewire.wireplumber.extraConfig = {
    alsa-config-xxx = {
      "monitor.alsa.rules" = [
        # Fixes crackling
        {
          matches = [
            {
              "node.name" = "~alsa_input.*";
            }
            {
              "node.name" = "~alsa_output.*";
            }
          ];
          actions = {
            update-props = {
              "audio.format" = "S16LE";
              "audio.rate" = 48000;
              "api.alsa.period-size" = 4096;
              "api.alsa.period-num" = 6;
              "api.alsa.headroom" = 512;
            };
          };
        }
      ];
    };
  };

  environment.pathsToLink = [ "/share/alsa/ucm2" ];
  environment.systemPackages = [
    pkgs.alsa-ucm-conf
    sdm845-alsa-ucm
  ];
  environment.variables.ALSA_CONFIG_UCM2 = ucm-env;
  systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = ucm-env;
  systemd.user.services.pipewire-pulse.environment.ALSA_CONFIG_UCM2 = ucm-env;
  systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = ucm-env;
  systemd.services.pipewire.environment.ALSA_CONFIG_UCM2 = ucm-env;
  systemd.services.pipewire-pulse.environment.ALSA_CONFIG_UCM2 = ucm-env;
  systemd.services.wireplumber.environment.ALSA_CONFIG_UCM2 = ucm-env;
}
