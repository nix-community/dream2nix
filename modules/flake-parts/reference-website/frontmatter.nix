{lib}: rec {
  getReadme = modulepath: modulename: let
    readme = modulepath + "/README.md";
    readmeContents =
      if (builtins.pathExists readme)
      then (builtins.readFile readme)
      else throw "No README.md found for module ${modulename} (expected at ${readme})";
  in
    readmeContents;

  getFrontmatterString = modulepath: modulename: let
    content = getReadme modulepath modulename;
    parts = lib.splitString "---" content;
    # Partition the parts into the first part (the readme content) and the rest (the metadata)
    parsed = builtins.partition ({index, ...}:
      if index >= 2
      then false
      else true) (
      lib.filter ({index, ...}: index != 0) (lib.imap0 (index: part: {inherit index part;}) parts)
    );
    meta = (builtins.head parsed.right).part;
  in
    if (builtins.length parts >= 3)
    then meta
    else
      throw ''
        TOML Frontmatter not found in README.md for module ${modulename}

        Please add the following to the top of your README.md:

        ---
        description = "Your description here"
        categories = [ "Your categories here" ]
        features = [ "inventory" ]
        ---
        ...rest of your README.md...
      '';
}
