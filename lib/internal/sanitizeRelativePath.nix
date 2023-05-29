{lib, ...}: let
  l = builtins // lib;

  sanitizeRelativePath = path:
    l.removePrefix "/" (l.toString (l.toPath "/${path}"));
in
  sanitizeRelativePath
