# Taken from https://gitlab.postmarketos.org/postmarketOS/swclock-offset
{ config, ... }:
let
  rtc_sys_node = "/sys/class/rtc/rtc0/since_epoch";
  offset_directory = "${config.xxx.persist.path}/cache/swclock-offset";
  offset_file = "${offset_directory}/offset-storage";
in
{
  boot.initrd.kernelModules = [
    "rtc_pm8xxx"
  ];

  # RTC (Real-Time Clock) is not writable so we use this to store an offset
  systemd.services.swclock-offset-boot = {
    description = "Setting the system time according to an offset file";
    wantedBy = [ "sysinit.target" ];
    before = [
      "systemd-fsck-root.service"
      "systemd-fsck@.service"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = 0;
    };
    script = ''
      if [ ! -f ${rtc_sys_node} ]; then
        echo "rtc sys node not found, skipping"
        exit 0
      fi

      if [ ! -f ${offset_file} ]; then
        echo "offset storage file not found, skipping"
        exit 0
      fi

      hwclock_epoch=$(cat ${rtc_sys_node})
      offset_epoch=$(cat ${offset_file})
      swclock_epoch=$((hwclock_epoch + offset_epoch))

      date -u -s @$swclock_epoch > /dev/null
    '';
  };

  systemd.services.swclock-offset-shutdown = {
    description = "Writing the offset between system time and RTC to a file";
    wantedBy = [
      "shutdown.target"
      "reboot.target"
      "halt.target"
    ];
    before = [
      "shutdown.target"
      "reboot.target"
      "halt.target"
    ];
    unitConfig.DefaultDependencies = "no";
    script = ''
      if [ ! -f ${rtc_sys_node} ]; then
        echo "rtc sys node not found, skipping"
        exit 0
      fi

      if [ ! -d ${offset_directory} ]; then
        mkdir -p ${offset_directory}
      fi

      swclock_epoch=$(date -u +%s)
      hwclock_epoch=$(cat ${rtc_sys_node})
      offset_epoch=$((swclock_epoch - hwclock_epoch))

      echo $offset_epoch > ${offset_file}
      # make sure offset gets written to disk
      sync
    '';
  };
}
