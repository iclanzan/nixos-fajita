{
  firefox-esr-140-unwrapped,
  fetchFirefoxAddon,
  fetchFromGitLab,
  mkEnvWrapper,
  runCommand,
  wrapFirefox,
  ...
}:
let
  profile = ''"$HOME/Local/.state/firefox"'';
  # Unexhaustive list of settings:
  # https://searchfox.org/firefox-main/source/modules/libpref/init/StaticPrefList.yaml
  firefox = firefox-esr-140-unwrapped // {
    requireSigning = false;
    allowAddonSideload = true;
  };
  ublock = fetchFirefoxAddon {
    name = "ublock"; # Has to be unique!
    url = "https://addons.mozilla.org/firefox/downloads/file/4814095/ublock_origin-1.71.0.xpi";
    sha256 = "sha256-R/eIofwsAUgwswuw75WIYVcBuYxSZfsZuM9Lp3mEn+s=";
  };
  firefoxExtraPolicies = {
    Homepage = {
      StartPage = "previous-session";
    };
    DisableFirefoxAccounts = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableTelemetry = true;
    DontCheckDefaultBrowser = true;
    EnableTrackingProtection = {
      Value = true;
      Cryptomining = true;
      Fingerprinting = true;
    };
    FirefoxHome = {
      Pocket = false;
      Snippets = false;
    };
    OfferToSaveLogins = false;
    PasswordManagerEnabled = false;
    PromptForDownloadLocation = false;
    SearchEngines.Default = "DuckDuckGo";
    ShowHomeButton = false;
    UserMessaging = {
      ExtensionRecommendations = false;
      SkipOnboarding = true;
    };
  };
in
mkEnvWrapper {
  name = "firefox";
  pkg =
    let
      mobile-config = fetchFromGitLab {
        domain = "gitlab.postmarketos.org";
        owner = "postmarketOS";
        repo = "mobile-config-firefox";
        rev = "4.6.0";
        hash = "sha256-tISfxN/04spgtKStkkn+zlCtFU6GbtwuZubqpGN2olA=";
      };
      mobileConfigDir = runCommand "mobile-config-firefox" { } ''
        mkdir -p $out/mobile-config-firefox/{common,userChrome,userContent}

        cp ${mobile-config}/src/common/*.css $out/mobile-config-firefox/common/
        cp ${mobile-config}/src/userChrome/*.css $out/mobile-config-firefox/userChrome/
        cp ${mobile-config}/src/userContent/*.css $out/mobile-config-firefox/userContent/

        (cd $out/mobile-config-firefox && find common -name "*.css" | sort) >> $out/mobile-config-firefox/userChrome.files
        (cd $out/mobile-config-firefox && find common -name "*.css" | sort) >> $out/mobile-config-firefox/userContent.files

        (cd $out/mobile-config-firefox && find userChrome -name "*.css" | sort) > $out/mobile-config-firefox/userChrome.files
        (cd $out/mobile-config-firefox && find userContent -name "*.css" | sort) > $out/mobile-config-firefox/userContent.files

      '';

      mobileConfigAutoconfig = runCommand "mobile-config-autoconfig.js" { } ''
        substitute ${mobile-config}/src/mobile-config-autoconfig.js $out \
          --replace "/etc/mobile-config-firefox" "${mobileConfigDir}/mobile-config-firefox"
      '';

      mobileConfigPrefs = runCommand "mobile-config-prefs.js" { } ''
        # Remove the autoconfig setup lines since we handle that through extraPrefsFiles
        grep -v "general.config.filename" ${mobile-config}/src/mobile-config-prefs.js | \
        grep -v "general.config.obscure_value" | \
        grep -v "general.config.sandbox_enabled" > $out
      '';
    in
    wrapFirefox firefox {
      nixExtensions = [ ublock ];
      extraPolicies = firefoxExtraPolicies;
      extraPoliciesFiles = [ "${mobile-config}/src/policies.json" ];
      extraPrefsFiles = [
        mobileConfigAutoconfig
        mobileConfigPrefs
      ];
    };
  flags = "--profile ${profile}";
  preRun = "mkdir -p ${profile}";
}
