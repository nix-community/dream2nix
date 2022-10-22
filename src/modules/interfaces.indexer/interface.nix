{framework, ...}: let
  l = framework.lib;
  t = l.types;
in {
  options = {
    indexBin = l.mkOption {
      type = t.uniq (t.either t.package t.path);
      description = ''
        The program to run to index using the passed indexer arguments.
      '';
    };
  };
}
