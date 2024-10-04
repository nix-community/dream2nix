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
      description = "Shell command(s) that copies the vendored sources correctly in a rust derivation";
    };
    writeGitVendorEntries = {
      type = t.functionTo t.str;
      internal = true;
      description = "Shell command(s) that writes vendored git sources to .cargo/config so cargo uses the sources we vendored";
    };
  };
}
