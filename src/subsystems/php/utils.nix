{utils, ...}: {
  # composer.lock uses a less strict semver interpretation
  # ~1.2 -> >=1.2 <2.0.0 (instead of >=1.2.0 <1.3.0)
  # this is identical with ^1.2 in the semver standard
  satisfiesSemver = version: constraint: let
    minorTilde = l.match "^[~]([[:d:]]+[.][[:d:]]+)$" constraint;
    cleanConstraint =
      if minorTilde != null && l.length minorTilde >= 0
      then "^${l.head minorTilde}"
      else constraint;
    cleanVersion = l.removePrefix "v" version;
  in
    utils.satisfiesSemver cleanVersion cleanConstraint;
}
