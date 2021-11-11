dream2nixWithExternals:
cwd:
let
  dream2nix = import dream2nixWithExternals { };
  b = builtins;
  parsed = b.fromTOML (builtins.readFile "${cwd}/gomod2nix.toml");
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  serializePackages = inputData:
    lib.mapAttrsToList
      (goName: depAttrs: depAttrs // { inherit goName; })
      parsed;
  translated = dream2nix.utils.simpleTranslate "gomod2nix" rec {

    inputData = parsed;

    mainPackageName =
      let
        firstLine = (b.elemAt (lib.splitString "\n" (b.readFile "${cwd}/go.mod")) 0);
      in
        lib.last (lib.splitString "/" (b.elemAt (lib.splitString " " firstLine) 1));

    mainPackageVersion = "unknown";

    subsystemName = "go";

    subsystemAttrs = { };

    inherit serializePackages;

    mainPackageDependencies =
      lib.forEach
        (serializePackages parsed)
        (dep: {
            name = getName dep;
            version = getVersion dep;
        });

    getOriginalID = dependencyObject:
      null;

    getName = dependencyObject:
      dependencyObject.goName;

    getVersion = dependencyObject:
      lib.removePrefix "v" dependencyObject.sumVersion;

    getDependencies = dependencyObject: getDepByNameVer: dependenciesByOriginalID:
      [];

    getSourceType = dependencyObject: "git";

    sourceConstructors = {
      git = dependencyObject:
        {
          type = "git";
          version = getVersion dependencyObject;
          hash = dependencyObject.fetch.sha256;
          url = dependencyObject.fetch.url;
          rev = dependencyObject.fetch.rev;
        };
    };

  };
in
  dream2nix.utils.dreamLock.toJSON translated
