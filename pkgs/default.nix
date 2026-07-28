self: super:
let
  lib = super.lib;
  unlines = builtins.concatStringsSep "\n";
  mkScript =
    name: text:
    super.writeTextFile {
      name = name;
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!${self.stdenv.shell}
        ${text}
      '';
      checkPhase = ''
        ${self.shellcheck}/bin/shellcheck $out/bin/${name}
      '';
    };
  mkEnvWrapper =
    {
      name,
      pkg,
      bin ? name,
      env ? { },
      flags ? "",
      preRun ? "",
      postBuild ? (_: ""),
    }:
    let
      export = k: v: ''export ${k}="${v}"'';
      envStr = lib.mapAttrsToList export env |> unlines;
      wrapper = mkScript name ''
        ${preRun}
        ${envStr}
        exec "${pkg}/bin/${bin}" ${flags} "$@"
      '';
    in
    super.runCommand name { buildInputs = [ self.makeWrapper ]; } ''
      mkdir $out
      ln -s ${pkg}/* $out
      rm $out/bin
      mkdir $out/bin
      ln -s ${pkg}/bin/* $out/bin
      rm $out/bin/${bin}
      ln -s ${wrapper}/bin/${name} $out/bin/${name}
      ${postBuild "${wrapper}/bin/${name}"}
    '';
in
{
  mkEnvWrapper = mkEnvWrapper;
  mkScript = mkScript;
  fajita-install = self.callPackage ./fajita-install.nix { };
  firefox-mobile = self.callPackage ./firefox-mobile.nix { };
}
