{lib, ...}: let
  l = builtins // lib;

  sanitizePath = path: let
    absolute = (l.substring 0 1 path) == "/";
    sanitizedRelPath = l.removePrefix "/" (l.toString (l.toPath "/${path}"));
  in
    if absolute
    then "/${sanitizedRelPath}"
    else sanitizedRelPath;
in
  sanitizePath
