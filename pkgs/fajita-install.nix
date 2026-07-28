{
  btrfs-progs,
  cryptsetup,
  dosfstools,
  mkScript,
  util-linux,
  writeText,
  ...
}:
let
  sfdiskCommands = writeText "sfdisk-commands" ''
    label: gpt
    size=512MiB, type=uefi
    type=linux
  '';
  sfdisk = "${util-linux}/bin/sfdisk";
  mount = "${util-linux}/bin/mount";
  umount = "${util-linux}/bin/umount";
  btrfs = "${btrfs-progs}/bin";
  crypt = "${cryptsetup}/bin/cryptsetup";
in
mkScript "fajita-install" /* bash */ ''
  set -euo pipefail

  if (( $# < 3 )); then
    printf "Usage: %s <flake> <target-device> <encryption-password>\n" "$0"
    exit 1
  fi

  flake="$1"
  device="$2"
  pass="$3"

  echo "Partitioning disk"
  cat ${sfdiskCommands} | ${sfdisk} --wipe always "$device"

  partitions=$(${sfdisk} --quiet --list --output device "$device" | tail -n +2)
  boot=$(echo "$partitions" | head -1 | tail -1)
  root=$(echo "$partitions" | tail -1)

  echo "Formatting boot partition"
  ${dosfstools}/bin/mkfs.fat -F 32 -n nixosboot "$boot"
  echo "Formatting LUKS partition"
  echo -n "$pass" | ${crypt} luksFormat --label nixosluks "$root" -
  echo "Unlocking LUKS partition"
  echo -n "$pass" | ${crypt} luksOpen "$root" phonecrypt --key-file -
  echo "Creating BTRFS filesystem"
  ${btrfs}/mkfs.btrfs -L nixos /dev/mapper/phonecrypt

  mkdir -p /mnt

  ${mount} /dev/mapper/phonecrypt /mnt
  echo "Creating BTRFS subvolumes"
  ${btrfs}/btrfs subvolume create /mnt/root
  ${btrfs}/btrfs subvolume create /mnt/nix
  ${btrfs}/btrfs subvolume create /mnt/persist
  ${umount} /mnt

  echo "Mounting BRRFS subvolumes"
  ${mount} -o subvol=root /dev/mapper/phonecrypt /mnt
  mkdir /mnt/{boot,nix,persist}
  ${mount} "$boot" /mnt/boot
  ${mount} -o compress=zstd,noatime,subvol=nix /dev/mapper/phonecrypt /mnt/nix
  ${mount} -o compress=zstd,subvol=persist /dev/mapper/phonecrypt /mnt/persist

  echo "Installing NixOS"
  nixos-install --no-channel-copy --no-root-password --root /mnt --flake "$flake"

  echo "Cleaning up"
  ${umount} --recursive /mnt
  ${crypt} close phonecrypt

  echo "Done!"
''
