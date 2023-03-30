{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.fetch-pip = {
    hash = l.mkOption {
      type = t.str;
      description = ''
        hash for the fixed output derivation
      '';
    };
    pypiSnapshotDate = l.mkOption {
      type = t.str;
      description = ''
        maximum release date for packages
        Choose any date from the past.
      '';
      example = "2023-01-01";
    };
    nameSuffix = l.mkOption {
      type = t.str;
      default = "python-requirements";
      description = ''
        suffix of the fetcher derivation name
      '';
    };
    noBinary = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        enforce source downloads for these package names
      '';
    };
    onlyBinary = l.mkOption {
      type = t.bool;
      default = false;
      description = ''
        restrict to binary releases (.whl)
        this allows buildPlatform independent fetching
      '';
    };
    python = l.mkOption {
      type = t.package;
      default = config.deps.python;
      description = ''
        Specify the python version for which the packages should be downloaded.
        Pip needs to be executed from that specific python version.
        Pip accepts '--python-version', but this works only for wheel packages.
      '';
    };
    pipFlags = l.mkOption {
      type = t.listOf t.str;
      description = ''
        hash for the fixed output derivation
      '';
      default = [];
    };
    pipVersion = l.mkOption {
      type = t.str;
      default = "23.0";
      description = ''
        the pip version used for fetching
      '';
      example = "23.1";
    };
    requirementsList = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        list of strings of requirements.txt entries
      '';
    };
    requirementsFiles = l.mkOption {
      type = t.listOf t.path;
      default = [];
      description = ''
        list of requirements.txt files
      '';
    };
    writeDependencyTree = l.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Write "dependencies.json" to $out, documenting which package depends on which.
      '';
    };
  };
}
