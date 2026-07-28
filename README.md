# NixOS on OnePlus 6T

This repository exposes a Nix flake that allows you to quickly get NixOS up and running on a OnePlus 6T with full-disk encryption, impermanence and Phosh.

## Getting started

Having acquired a OnePlus 6T, the first objective is to unlock the bootloader:

- On Android open Settings, go to "About" and tap on the "Build number" box 10 times until the "You are now a developer" message appears.
- Go back to Settings, then go to "System" and then "Developer options" and toggle on "Enable OEM unlocking".
- Restart the phone and hold both _Volume Up_ and _Volume down_ buttons while booting in order to enter "Fastboot mode".
- Attach phone to computer using USB-C cable and run `fastboot oem unlock`.
- Follow instructions on phone; it will wipe the device.

Next install U-Boot as a (chained) bootloader:

- Build U-Boot
  ```sh
  nix build .#uboot-img
  ```
- Flash U-Boot to phone in _Fastboot mode_
  ```sh
  fastboot erase dtbo flash boot ./result reboot
  ```

Enter U-Boot _mass storage mode_:

- Connected phone to another `aarch64` device already running NixOS
- Hold _Volume down_ while booting phone to enter U-Boot menu
- Select "Enter mass storage mode"

Install NixOS on the phone from the device already running NixOS:

- Run `lsblk` and identify the phone storage (e.g. `/dev/sda`)
- Build installer script from this repository
  ```sh
  nix build .#fajita-install
  ```
- Use the installer script to install NixOS
  ```sh
  password=my-secret-encryption-password
  ./result/fajita-install/bin/fajita-install .#fajita /dev/sda "$password"
  ```

Done! You can now reboot into your NixOS on OnePlus 6T and log in with the password `123000`. Root has the same password and can be accessed over SSH so you can further customize your NixOS installation.

## Known issues

- Incoming audio is distorted during VoLTE calls.
- All 3 cameras are working but none produce decent pictures.
- Occasionally getting “Qualcomm CrashDump Mode” on boot right before Phosh loads.
- Tri-state button is not wired up; I don’t use it so I didn’t bother.
- Mobile data sometimes stops working; toggling it from _Quick Settings_ restores connectivity.
- Bluetooth sometimes stops working and requires a device reboot.
- Every now and then Phosh enters a broken state where you can still drag the top bar drawer but nothing else works; requires a hard reset.
- `nixos-rebuild switch` always causes Phosh to restart; sometimes it fails to restart but can be started remotely (`systemctl start phosh`).
