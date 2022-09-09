{lib, ...}: let
  l = lib // builtins;

  inherit (import ./semver.nix {inherit lib;}) satisfies;

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
      m = l.match "^(.)*v([[:d:]]+[.].*)$" c;
    in
      if m != null && l.length m > 0
      then l.concatStrings m
      else c;
    cleanConstraint = removeV (wildcard (tilde (removeSuffix constraint)));
    cleanVersion = removeX (l.removePrefix "v" (removeSuffix version));
  in
    (l.any (x: constraint == x) ["*" "@dev" "@master" "@dev-master"])
    || (version == constraint)
    || (satisfies cleanVersion cleanConstraint);

  trim = s: l.head (l.match "^[[:space:]]*(.*[^[:space:]])[[:space:]]*$" s);
  splitAlternatives = v: let
    # handle version alternatives: ^1.2 || ^2.0
    clean = l.replaceStrings ["||"] ["|"] v;
  in
    map trim (l.splitString "|" clean);
  splitConjunctives = v: let
    clean = l.replaceStrings ["," " - " " -" "- "] [" " "-" "-" "-"] v;
  in
    map trim (l.splitString " " clean);
in {
  # 1.0.2 ~1.0.1
  # matching a version with semver
  satisfiesSemver = version: constraint:
    l.any
    (c:
      l.all
      (satisfiesSemverSingle version)
      (splitConjunctives c))
    (splitAlternatives constraint);

  # 1.0|2.0 ^2.0
  # matching multiversion like the one in `provide` with semver
  multiSatisfiesSemver = multiversion: constraint: let
    satisfies = v: c: (v == "") || (v == "*") || (satisfiesSemverSingle v c);
  in
    l.any
    (c: l.any (v: l.all (satisfies v) (splitConjunctives c)) (splitAlternatives multiversion))
    (splitAlternatives constraint);
}
