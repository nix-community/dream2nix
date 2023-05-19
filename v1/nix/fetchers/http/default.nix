{
  utils ? null,
  fetchurl,
  lib,
  hashFile ? utils.hashFile,
  mkDerivation,
  extractSource ?
    import ../extractSource.nix {
      inherit lib mkDerivation;
    },
  ...
}: {
  inputs = [
    "url"
  ];

  outputs = {url, ...}: let
    b = builtins;
  in {
    calcHash = algo:
      hashFile algo (b.fetchurl {
        inherit url;
      });

    fetched = hash: let
      drv =
        if hash != null && lib.stringLength hash == 40
        then
          fetchurl {
            inherit url;
            sha1 = hash;
          }
        else
          fetchurl {
            inherit url hash;
          };

      drvSanitized = drv.overrideAttrs (old: {
        name = lib.strings.sanitizeDerivationName old.name;
      });

      extracted = extractSource {
        source = drvSanitized;
      };
    in
      extracted;
  };
}
