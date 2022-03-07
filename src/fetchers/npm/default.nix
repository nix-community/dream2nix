{
  fetchurl,
  lib,
  python3,
  utils,
  ...
}: let
  b = builtins;
in rec {
  inputs = ["pname" "version"];

  versionField = "version";

  defaultUpdater = "npmNewestReleaseVersion";

  # becuase some node packages contain submodules like `@hhhtj/draw.io`
  # the amount of arguments can vary and a custom parser is needed
  parseParams = params:
    if b.length params == b.length inputs
    then
      lib.listToAttrs
      (lib.forEach
        (lib.range 0 ((lib.length inputs) - 1))
        (
          idx:
            lib.nameValuePair
            (lib.elemAt inputs idx)
            (lib.elemAt params idx)
        ))
    else if b.length params == (b.length inputs) + 1
    then
      parseParams [
        "${b.elemAt params 0}/${b.elemAt params 1}"
        (b.elemAt params 2)
      ]
    else
      throw ''
        Wrong number of arguments provided in shortcut for fetcher 'npm'
        Should be npm:${lib.concatStringsSep "/" inputs}
      '';

  # defaultUpdater = "";

  outputs = {
    pname,
    version,
  } @ inp: let
    b = builtins;

    submodule = lib.last (lib.splitString "/" pname);
    url = "https://registry.npmjs.org/${pname}/-/${submodule}-${version}.tgz";
  in {
    calcHash = algo:
      utils.hashPath algo (
        b.fetchurl {inherit url;}
      );

    fetched = hash: let
      source =
        (fetchurl {
          inherit url;
          sha256 = hash;
        })
        .overrideAttrs (old: {
          outputHashMode = "recursive";
        });
    in
      utils.extractSource {
        inherit source;
      };
  };
}
