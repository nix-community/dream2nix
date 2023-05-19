{
  pkgs,
  lib,
  utils,
  ...
}: {
  inputs = [
    "url"
  ];

  outputs = {url, ...}: let
    b = builtins;
  in {
    calcHash = algo:
      utils.hashFile algo (b.fetchurl {
        inherit url;
      });

    fetched = hash: let
      drv =
        if hash != null && lib.stringLength hash == 40
        then
          pkgs.fetchurl {
            inherit url;
            sha1 = hash;
          }
        else
          pkgs.fetchurl {
            inherit url hash;
          };

      drvSanitized = drv.overrideAttrs (old: {
        name = lib.strings.sanitizeDerivationName old.name;
      });

      extracted = utils.extractSource {
        source = drvSanitized;
      };
    in
      extracted;
  };
}
