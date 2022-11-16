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
      utils.hashFile algo (b.fetchArchive {
        inherit url;
      });

    fetched = hash: let
      drv =
        if hash != null && lib.stringLength hash == 40
        then
          pkgs.fetchzip {
            inherit url;
            sha1 = hash;
          }
        else
          pkgs.fetchzip {
            inherit url hash;
          };

      drvSanitized = drv.overrideAttrs (old: {
        name = lib.strings.sanitizeDerivationName old.name;
      });
    in
      drvSanitized;
  };
}
