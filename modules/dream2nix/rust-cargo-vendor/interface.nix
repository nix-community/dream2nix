{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.rust-cargo-vendor = l.mapAttrs (_: l.mkOption) {
    vendoredSources = {
      type = t.package;
      description = "Path to vendored sources";
    };
    copyVendorDir = {
      type = t.functionTo (t.functionTo t.str);
      internal = true;
      description = "Makes shell command(s) that copies the vendored sources correctly in a rust derivation";
    };
    getRootSource = {
      type = t.functionTo (t.functionTo t.path);
      internal = true;
      description = "Gets root source for a given package";
    };
    writeGitVendorEntries = {
      type = t.functionTo t.str;
      internal = true;
      description = "Makes shell command(s) that writes vendored git sources to .cargo/config so cargo uses the sources we vendored";
    };
    replaceRelativePathsWithAbsolute = {
      type = t.functionTo t.str;
      internal = true;
      description = "Makes shell commands that will replace relative dependency paths with absolute paths in Cargo.toml";
    };
  };
}
