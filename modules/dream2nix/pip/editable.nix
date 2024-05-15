{
  lib,
  findRoot,
  writeText,
  unzip,
  pyEnv,
  editables,
  rootName,
  sources,
}: let
  args = writeText "args" (builtins.toJSON {
    inherit findRoot unzip rootName pyEnv editables sources;
    inherit (pyEnv) sitePackages;
  });
in ''
  source <(${pyEnv}/bin/python ${./editable.py} ${args})
''
