{lib, ...}: let
  l = builtins // lib;

  idToLicenseKey =
    l.mapAttrs'
    (n: v: l.nameValuePair (l.toLower (v.spdxId or v.fullName or n)) n)
    l.licenses;

  # Parses a string like "Unlicense OR MIT" to `["unlicense" "mit"]`
  # TODO: this does not parse `AND` or `WITH` or paranthesis, so it is
  # pretty hacky in how it works. But for most cases this should be okay.
  parseSpdxId = _id: let
    # some spdx ids might have paranthesis around them
    id = l.removePrefix "(" (l.removeSuffix ")" _id);
    licenseStrings = l.map l.toLower (l.splitString " OR " id);
    _licenses = l.map (string: idToLicenseKey.${string} or null) licenseStrings;
    licenses = l.filter (license: license != null) _licenses;
  in
    licenses;
in
  parseSpdxId
