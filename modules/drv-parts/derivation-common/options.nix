{lib}: let
  l = lib // builtins;
  t = l.types;
  optNullOrBool = l.mkOption {
    type = t.nullOr t.bool;
    default = null;
  };
  optListOfStr = l.mkOption {
    type = t.nullOr (t.listOf t.str);
    default = null;
  };
  optNullOrStr = l.mkOption {
    type = t.nullOr t.str;
    default = null;
  };
in {
  # basic arguments
  args = l.mkOption {
    type = t.nullOr (t.listOf (t.oneOf [t.str t.path]));
    default = null;
  };
  outputs = l.mkOption {
    type = t.nullOr (t.listOf t.str);
    default = ["out"];
  };
  __contentAddressed = optNullOrBool;
  __structuredAttrs = lib.mkOption {
    type = t.nullOr t.bool;
    default = null;
  };

  # advanced attributes
  allowedReferences = optListOfStr;
  allowedRequisites = optListOfStr;
  disallowedReferences = optListOfStr;
  disallowedRequisites = optListOfStr;
  exportReferenceGraph = lib.mkOption {
    # TODO: make type stricter
    type = t.nullOr (t.listOf (t.either t.str t.package));
    default = null;
  };
  impureEnvVars = optListOfStr;
  outputHash = optNullOrStr;
  outputHashAlgo = optNullOrStr;
  outputHashMode = optNullOrStr;
  passAsFile = optListOfStr;
  preferLocalBuild = optListOfStr;
  allowSubstitutes = optNullOrBool;
}
