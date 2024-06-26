{
  lib,
  findRoot,
  writeText,
  unzip,
  pyEnv,
  editables,
  rootName,
}: let
  args = writeText "args" (builtins.toJSON {
    inherit findRoot unzip rootName pyEnv editables;
    inherit (pyEnv) sitePackages;
    inherit (builtins) storeDir;
  });
in ''
  source <(${pyEnv}/bin/python ${./editable.py} ${args})
''
