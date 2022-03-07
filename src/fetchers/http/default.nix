{
  lib,
  fetchurl,
  utils,
  ...
}: {
  inputs = [
    "url"
  ];

  outputs = {url, ...} @ inp: let
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

      extracted = utils.extractSource {
        source = drvSanitized;
      };
    in
      extracted;
  };
}
