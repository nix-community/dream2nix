let
  b = builtins;

  # loads attrs either from s:
  #   - json file
  #   - json string
  #   - attrset (no changes)
  loadAttrs = input:
    if b.isPath input
    # discarding context here should be fine since we read the text from
    # a path, which will be realized and nothing else will need to be realized
    then b.fromJSON (b.unsafeDiscardStringContext (b.readFile input))
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
      packagesDir = "./dream2nix-packages";
      projectRoot = null;
      repoName = null;
    };
  in
    defaults // config;
in {
  inherit loadConfig;
}
