{
  lib,
  pkgs,
  config,
  ...
}:
let
  baseFw = pkgs.fetchFromGitLab {
    owner = "sdm845-mainline";
    repo = "firmware-oneplus-sdm845";
    rev = "3e31a0c3e5a061645c09f805387b49fa9d35acbf";
    hash = "sha256-DeOlhchDGi0Pso3w8ZlM7q3Tdkmt3Ji+GyEmepkISTE=";
  };

  firmware =
    pkgs.runCommand "oneplus-sdm845-firmware"
      {
        inherit baseFw;
      }
      ''
        mkdir -p $out/lib/firmware
        cp -r $baseFw/lib/firmware/* $out/lib/firmware/
        chmod +w -R $out
        rm -rf $out/lib/firmware/postmarketos
        cp -r $baseFw/lib/firmware/postmarketos/* $out/lib/firmware
        ls -lah $out/lib/firmware/qcom/sdm845
      '';

  p81voltd = pkgs.stdenv.mkDerivation rec {
    pname = "81voltd";
    version = "1.1.0";

    src = pkgs.fetchFromGitLab {
      domain = "gitlab.postmarketos.org";
      owner = "modem";
      repo = "81voltd";
      rev = "v${version}";
      sha256 = "sha256-kvkIOw529b2sfj2zi12OX6nuuBRkmjTcXd3e5jAsoeU=";
    };

    nativeBuildInputs = with pkgs; [
      meson
      ninja
      pkg-config
    ];

    buildInputs = with pkgs; [
      glib
      libqmi
      libqrtr-glib
      protobufc
      modemmanager
      qrtr
    ];

    mesonBuildFlags = [
      "-Dqrtr_aidn=new"
    ];

    installPhase = ''
      install -Dm755 81voltd $out/bin/81voltd
    '';
  };

  q6voiced = pkgs.stdenv.mkDerivation rec {
    pname = "q6voiced";
    version = "0.2.1";

    src = pkgs.fetchFromGitLab {
      domain = "gitlab.postmarketos.org";
      owner = "postmarketOS";
      repo = "q6voiced";
      rev = version;
      sha256 = "0130s2iqywrbxgi3mmxxpic7l5kfhb7mvwpykzjyxx2icn065hvz";
    };

    buildInputs = with pkgs; [
      alsa-lib
      dbus
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      meson
      ninja
    ];
  };
in
{
  imports = [
    ./rtc.nix
    ./sound.nix
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = false;
  };
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.initrdBin = [ pkgs.util-linux ];
  boot.initrd.services.udev.rules = ''
    SUBSYSTEM=="block", ACTION!="remove", ENV{ID_PART_ENTRY_NAME}=="userdata", RUN+="${pkgs.util-linux}/bin/losetup --partscan --find --sector-size 4096 --loop-ref userdata /dev/%k"
  '';
  boot.blacklistedKernelModules = [
    "qcrypto"
    "rpmsg_wwan_ctrl"
  ];
  boot.initrd.includeDefaultModules = false;
  boot.initrd.systemd.tpm2.enable = false;

  # Our custom kernel config is missing a lot of modules
  boot.initrd.allowMissingModules = true;

  boot.initrd.kernelModules = [
    "qcom_pd_mapper"
    "sd_mod"
    "scsi_mod"
    "dm_mod"
    "ufshcd-core"
    "ufs-qcom"
    "phy-qcom-qmp-ufs"

    "i2c_qcom_geni"
    "rmi_core"
    "rmi_i2c"
    "qcom_spmi_haptics"

    "evdev"
    "uinput"
  ];
  boot.kernelParams = [
    "clk_ignore_unused"
    "pd_ignore_unused"
    "arm64.nopauth"

    "console=ttyMSM0,115200n8"
    # "console=ttyGS0,115200" # Serial over USB

    "-quiet"
  ];

  hardware.deviceTree.name = "qcom/sdm845-oneplus-fajita.dtb";
  hardware.firmware = [
    firmware
    pkgs.linux-firmware
  ];
  hardware.enableRedistributableFirmware = true;

  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    jack.enable = true;
    alsa = {
      enable = true;
      support32Bit = false;
    };
  };

  # Allows pipewire to acquire realtime priority
  security.rtkit.enable = true;

  hardware.graphics.enable32Bit = false;
  hardware.bluetooth.enable = true;

  hardware.sensor.iio = {
    enable = true;
    package = pkgs.stdenv.mkDerivation {
      pname = "iio-sensor-proxy";
      version = "3.9";

      src = pkgs.fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "hadess";
        repo = "iio-sensor-proxy";
        rev = "0085ddf8ecb173a1c5fcf2344aa40e561125354f";
        hash = "sha256-2N/4Fp6QtAhgEzX9cHEDJhFtRsyrtZ80I2jdHdeEmxA=";
      };

      postPatch = ''
        # upstream meson.build currently doesn't have an option to change the default polkit dir
        substituteInPlace data/meson.build \
          --replace 'polkit_policy_directory' "'$out/share/polkit-1/actions'"
      '';

      buildInputs = [
        pkgs.libgudev
        pkgs.systemd
        pkgs.polkit
        pkgs.libssc
      ];

      nativeBuildInputs = [
        pkgs.meson
        pkgs.cmake
        pkgs.glib
        pkgs.libxml2
        pkgs.ninja
        pkgs.pkg-config
        pkgs.udevCheckHook
      ];

      mesonFlags = [
        (lib.mesonOption "udevrulesdir" "${placeholder "out"}/lib/udev/rules.d")
        (lib.mesonOption "systemdsystemunitdir" "${placeholder "out"}/lib/systemd/system")
        (lib.mesonOption "ssc-support" "enabled")
      ];

      doInstallCheck = true;
    };
  };
  systemd.services.iio-sensor-proxy = {
    requires = [ "hexagonrpcd-sdsp.service" ];
    after = [ "hexagonrpcd-sdsp.service" ];
    overrideStrategy = "asDropin";
    serviceConfig = {
      Restart = "always";
      # hexagonrpcd-sdsp.service is marked active too early
      RestartSec = "5s";
      RestrictAddressFamilies = [
        "AF_QIPCRTR"
        "AF_LOCAL"
      ];
    };
  };
  services.udev.extraRules = builtins.concatStringsSep "\n" [
    # iio-sensor-proxy with libssc: accelerometer mount matrix
    ''SUBSYSTEM=="misc", KERNEL=="fastrpc-*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, 1, 0; 0, 0, -1"''
    # iio-sensor-proxy with libssc: enable sensors
    ''SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity ssc-light ssc-compass"''
    # prevent from getting woken up by volume up / down in Phosh / Gnome Mobile
    ''SUBSYSTEM=="input", KERNEL=="event*", ENV{GM_WAKEUP_KEY_114}="0", ENV{GM_WAKEUP_KEY_115}="0"''
    # hide android partitions
    ''SUBSYSTEM=="block", KERNEL=="sd[a-f][0-9]*", ENV{UDISKS_IGNORE}="1"''
  ];

  # Enables the Performance power mode in Gnome Settings
  services.tuned = {
    enable = true;
    # Set performance as default for a smoother desktop
    ppdSettings.main.default = "performance";
  };

  systemd.services.qca-bluetooth =
    let
      path = lib.makeBinPath (
        with pkgs;
        [
          config.hardware.bluetooth.package
          coreutils-full
          gawk
          unixtools.script
        ]
      );
      script = pkgs.writeShellScript "qca-bluetooth.sh" ''
        set -x
        trap 'sleep 1' DEBUG # Sleep 1 second before every command execution
        export PATH="${path}:$PATH"

        SERIAL=$(grep -o "serialno.*" /proc/cmdline | cut -d" " -f1)
        BT_MAC=$(echo "$SERIAL-BT" | sha256sum | awk -v prefix=0200 '{printf("%s%010s\n", prefix, $1)}')
        BT_MAC=$(echo "$BT_MAC" | cut -c1-12 | sed 's/\(..\)/\1:/g' | sed '$s/:$//')

        script -qc "btmgmt --timeout 3 -i hci0 power off"
        script -qc "btmgmt --timeout 3 -i hci0 public-addr \"$BT_MAC\""
      '';
    in
    {
      description = "Setup the bluetooth interface";
      wantedBy = [
        "multi-user.target"
        "bluetooth.service"
      ];
      script = toString script;
      serviceConfig = {
        User = "root";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

  nixpkgs.hostPlatform = lib.recursiveUpdate (lib.systems.elaborate "aarch64-linux") {
    linux-kernel.target = "vmlinuz.efi";
    linux-kernel.installTarget = "zinstall";
  };

  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./kernel.nix { });

  # Boot entries are too long; try to shorten them
  system.nixos.label = "";

  systemd.services.tqftpserv =
    let
      tqftpserv = pkgs.tqftpserv.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          owner = "linux-msm";
          repo = "tqftpserv";
          rev = "443c82aadae2862dc7c12af48ac0b900f4bb0fe7";
          hash = "sha256-cwoAinvO2bQ6Ylx1zzh5ycE7om2vgk9uqyDJhpy6jP4=";
        };
      });
    in
    {
      description = "Qualcomm QRTR TFTP services (tqftpserv)";
      wantedBy = [ "multi-user.target" ];
      before = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${tqftpserv}/bin/tqftpserv -v";
        Restart = "on-failure";
        RestartSec = "2s";
        User = "root";
        Group = "root";
      };
    };

  systemd.services.rmtfs = {
    description = "Qualcomm Remote Filesystem Daemon (rmtfs)";
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.rmtfs}/bin/rmtfs -r -P -s";
      Restart = "on-failure";
      RestartSec = "2s";
      User = "root";
      Group = "root";
    };
  };

  systemd.services.msm-modem-uim-selection = {
    enable = true;
    before = [ "ModemManager.service" ];
    wantedBy = [ "ModemManager.service" ];
    path = with pkgs; [
      libqmi
      gawk
      gnugrep
    ];
    script = ''
      set -eu

      SIM_WAIT_TIME=4
      QMICLI_MODEM=

      # Prepare a qmicli command with desired modem path.
      # The modem may appear after some delay, wait for it.
      count=0
      while [ -z "$QMICLI_MODEM" ] && [ "$count" -lt "45" ]
      do
        # Check if QRTR is available for new devices.
        if qmicli --silent -pd qrtr://0 --uim-noop > /dev/null
        then
          QMICLI_MODEM="qmicli --silent -pd qrtr://0"
          echo "Using qrtr://0"
        fi
        sleep 1
        count=$((count+1))
      done
      echo "Waited $count seconds for modem device to appear"

      if [ -z "$QMICLI_MODEM" ]
      then
        echo 'No modem available.'
        exit 2
      fi

      QMI_CARDS=$($QMICLI_MODEM --uim-get-card-status)

      # Fail if all slots are empty but wait a bit for the sim to appear.
      count=0
      while ! printf "%s" "$QMI_CARDS" | grep -Fq "Card state: 'present'"
      do
        if [ "$count" -ge "$SIM_WAIT_TIME" ]
        then
          echo "No sim detected after $SIM_WAIT_TIME seconds."
          exit 0
        fi

        sleep 1
        count=$((count+1))
        QMI_CARDS=$($QMICLI_MODEM --uim-get-card-status)
      done
      echo "Waited $count seconds for modem to come up"

      # Clear the selected application in case the modem is in a bugged state
      if ! printf "%s" "$QMI_CARDS" | grep -Fq "Primary GW:   session doesn't exist"
      then
        echo 'Application was already selected.'
        $QMICLI_MODEM --uim-change-provisioning-session='activate=no,session-type=primary-gw-provisioning' > /dev/null
      fi

      # Extract first available slot number and AID for usim application
      # on it. This should select proper slot out of two if only one UIM is
      # present or select the first one if both slots have UIM's in them.
      FIRST_PRESENT_SLOT=$(printf "%s" "$QMI_CARDS" | grep "Card state: 'present'" -m1 -B1 | head -n1 | cut -c7-7)
      FIRST_PRESENT_AID=$(printf "%s" "$QMI_CARDS" | grep "usim (2)" -m1 -A3 | tail -n1 | awk '{print $1}')

      if [ -z "$FIRST_PRESENT_AID" ]; then
        echo "No usim application found."
        exit 0
      fi

      echo "Selecting $FIRST_PRESENT_AID on slot $FIRST_PRESENT_SLOT"

      # Finally send the new configuration to the modem.
      $QMICLI_MODEM --uim-change-provisioning-session="slot=$FIRST_PRESENT_SLOT,activate=yes,session-type=primary-gw-provisioning,aid=$FIRST_PRESENT_AID" > /dev/null

      exit $?
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  systemd.services.gnss = {
    description = "Qualcomm GNSS Modem Setup";
    wantedBy = [ "default.target" ];
    # These commands need to run after qrtr is up, MM seems to be late enough that
    # this is the case.
    # Ideally there would be a /dev or sysfs path we could add
    # a ConditionPathExists= on...
    after = [ "ModemManager.service" ];
    requires = [ "ModemManager.service" ];
    startLimitIntervalSec = 300; # Give up after 5 minutes
    startLimitBurst = 10;
    serviceConfig = {
      Type = "oneshot";
      ExecStart =
        let
          qmicli = "${pkgs.libqmi}/bin/qmicli  -d qrtr://0";
        in
        [
          "${qmicli} --loc-set-engine-lock=mt"
          "${qmicli} --loc-set-nmea-types=all"
        ];
      Restart = "on-failure";
      RestartSec = 30;
    };
  };

  # VoLTE support (required on T-Mobile)
  systemd.services.p81voltd = {
    description = "QMI IMS Data service";
    enable = true;
    before = [ "ModemManager.service" ];
    wantedBy = [ "ModemManager.service" ];
    serviceConfig = {
      ExecStart = "${p81voltd}/bin/81voltd";
      Restart = "always";
      RestartSec = "5";
    };
  };

  # Makes audio in phone calls work
  systemd.services.q6voiced = {
    description = "Enable q6voice audio when call is performed with ModemManager";
    wantedBy = [ "multi-user.target" ];
    after = [
      "ModemManager.service"
      "dbus.service"
    ];
    requires = [ "dbus.service" ];
    serviceConfig = {
      ExecStart = "${q6voiced}/bin/q6voiced hw:0,6";
      Restart = "always";
    };
  };

  systemd.services.hexagonrpcd-sdsp =
    let
      dev = "/dev/fastrpc-sdsp";
      root = "${baseFw}/usr/share/qcom/sdm845/OnePlus/oneplus6";
    in
    {
      description = "Hexagonrpcd SDSP";
      wantedBy = [ "multi-user.target" ];
      # requires = [ "dev-fastrpc\\x2dsdsp.device" ];
      # after = [ "dev-fastrpc\\x2dsdsp.device" ];
      unitConfig.ConditionPathExists = [ dev ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 3;
      };
      script = ''
        ${pkgs.hexagonrpc}/bin/hexagonrpcd -R "${root}" -d sdsp -f ${dev} -s
      '';
    };

  environment.variables.GST_PLUGIN_FEATURE_RANK = "v4l2vp8dec:SECONDARY,v4l2vp8enc:NONE,v4l2vp9dec:SECONDARY,v4l2h264dec:SECONDARY,v4l2h264enc:NONE,v4l2h265dec:SECONDARY,v4l2h265enc:NONE,v4l2mpeg2dec:SECONDARY";
}
