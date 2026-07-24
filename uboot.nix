# `fastboot erase dtbo flash boot <image-file> reboot`
{
  fetchFromGitLab,
  runCommand,
  buildUBoot,
  xxd,
  bison,
  flex,
  openssl,
  gnutls,
  android-tools,
}:
let
  uboot = buildUBoot {
    version = "master";

    src = fetchFromGitLab {
      domain = "gitlab.postmarketos.org";
      owner = "tauchgang";
      repo = "u-boot";
      rev = "6bdfc2077b9d616d44ab2e70f8df5732502d651c";
      hash = "sha256-z1B787hlD9MsR51UmvPKVjgshwprbt0VWF1CwAV8Xvc=";
    };

    extraConfig = ''
      CONFIG_CMD_HASH=y
      CONFIG_CMD_BLKMAP=y
      CONFIG_BLKMAP=y
      CONFIG_CMD_UFETCH=y
      CONFIG_CMD_SELECT_FONT=y
      CONFIG_VIDEO_FONT_16X32=y
      CONFIG_BOOTDELAY=5
    '';

    extraMakeFlags = [ "DEVICE_TREE=qcom/sdm845-oneplus-fajita" ];
    defconfig = "qcom_defconfig qcom-phone.config";
    extraMeta.platforms = [ "aarch64-linux" ];
    nativeBuildInputs = [
      xxd
      bison
      flex
      openssl
      gnutls
      android-tools
    ];
    filesToInstall = [
      "u-boot*"
      "dts/upstream/src/arm64/qcom/sdm845-oneplus-fajita.dtb"
    ];
  };
in
runCommand "uboot-img"
  {
    nativeBuildInputs = [ android-tools ];
  }
  ''
    cp ${uboot}/u-boot-nodtb.bin ./u-boot-nodtb.bin
    gzip ./u-boot-nodtb.bin
    cat ./u-boot-nodtb.bin.gz ${uboot}/sdm845-oneplus-fajita.dtb > ubootwithdtb
    mkbootimg \
      --kernel ./ubootwithdtb \
      --base "0x0" \
      --ramdisk /dev/null \
      --kernel_offset "0x8000" \
      --pagesize 4096 \
      -o $out
  ''
