{
  utils,
  lib,
  ...
}: let
  l = lib // builtins;

  # composer.lock uses a less strict semver interpretation
  # ~1.2 -> >=1.2 <2.0.0 (instead of >=1.2.0 <1.3.0)
  # ~1   -> >=1.0 <2.0.0
  # this is identical with ^1.2 in the semver standard
  #
  # remove v from version strings: ^v1.2.3 -> ^1.2.3
  #
  # remove branch suffix: ^1.2.x-dev -> ^1.2
  #
  satisfiesSemverSingle = version: constraint: let
    removeSuffix = c: let
      m = l.match "^(.*)[-][[:alpha:]]+$" c;
    in
      if m != null && l.length m >= 0
      then l.head m
      else c;
    removeX = l.strings.removeSuffix ".x";
    tilde = c: let
      m = l.match "^[~]([[:d:]]+.*)$" c;
    in
      if m != null && l.length m >= 0
      then "^${l.head m}"
      else c;
    wildcard = c: let
      m = l.match "^([[:d:]]+.*)[.][*x]$" c;
    in
      if m != null && l.length m >= 0
      then "^${l.head m}"
      else c;
    removeV = c: let
      m = l.match "^(.)v([[:d:]]+[.].*)$" c;
    in
      if m != null && l.length m > 0
      then l.concatStrings m
      else c;
    cleanConstraint = removeV (wildcard (tilde (removeSuffix constraint)));
    cleanVersion = removeX (l.removePrefix "v" (removeSuffix version));
  in
    (version == constraint)
    || (
      utils.satisfiesSemver
      cleanVersion
      cleanConstraint
    );

  splitAlternatives = v: let
    # handle version alternatives: ^1.2 || ^2.0
    trim = s: l.head (l.match "^[[:space:]]*([^[:space:]]*)[[:space:]]*$" s);
    clean = l.replaceStrings ["||"] ["|"] v;
  in
    map trim (l.splitString "|" clean);
in {
  # 1.0.2 ~1.0.1
  # matching a version with semver
  satisfiesSemver = version: constraint:
    l.any (satisfiesSemverSingle version) (splitAlternatives constraint);

  # 1.0|2.0 ^2.0
  # matching multiversion like the one in `provide` with semver
  multiSatisfiesSemver = multiversion: constraint: let
    satisfies = v: c: (v == "") || (v == "*") || (satisfiesSemverSingle v c);
  in
    l.any
    (c: l.any (v: satisfies v c) (splitAlternatives multiversion))
    (splitAlternatives constraint);
}
