{
  lib,
  findRoot,
  writeText,
  unzip,
  pyEnv,
  editables,
  rootName,
  drvs,
}: let
  args = writeText "args" (builtins.toJSON {
    inherit findRoot unzip rootName pyEnv editables;
    inherit (pyEnv) sitePackages;
    drvs =
      lib.mapAttrs (n: v: {
        inherit (v.public) out;
        inherit (v.mkDerivation) src;
      })
      drvs;
  });
in ''
  source <(${pyEnv}/bin/python ${./editable.py} ${args})
''
