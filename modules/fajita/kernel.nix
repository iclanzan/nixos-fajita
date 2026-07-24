{
  linuxManualConfig,
  ...
}:
let
  src = fetchTarball {
    url = "https://gitlab.com/sdm845-mainline/linux/-/archive/sdm845-7.1-rc1-r0/linux-sdm845-7.1-rc1-r0.tar.gz";
    sha256 = "sha256-/K74EnSqTkkNJAUe7+g7Rw+aqNVBO5dFyXrSwAKvsdc=";
  };
  modDirVersion = "7.1.0-rc1";
in
(linuxManualConfig {
  src = src;
  version = "${modDirVersion}";
  configfile = ./config.aarch64;
  features = {
    efiBootStub = true;
  };
  extraMeta = {
    platforms = [ "aarch64-linux" ];
    hydraPlatforms = [ "" ];
  };
}).overrideAttrs
  (old: {
    postUnpack = ''
      cp ${./arch-arm64-boot-dts-sdm845-Makefile} source/arch/arm64/boot/dts/qcom/Makefile
    '';
  })
