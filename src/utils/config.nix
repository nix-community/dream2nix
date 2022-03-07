let
  b = builtins;

  # loads attrs either from s:
  #   - json file
  #   - json string
  #   - attrset (no changes)
  loadAttrs = input:
    if b.isPath input
    then b.fromJSON (b.readFile input)
    else if b.isString input
    then b.fromJSON input
    else if b.isAttrs input
    then input
    else throw "input for loadAttrs must be json file or string or attrs";

  # load dream2nix config extending with defaults
  loadConfig = configInput: let
    config = loadAttrs configInput;
    defaults = {
      overridesDirs = [];
      packagesDir = "./packages";
      projectRoot = null;
      repoName = null;
    };
  in
    defaults // config;
in {
  inherit loadConfig;
}
