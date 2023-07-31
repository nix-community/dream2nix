{
  lib,
  pep508,
  pypa,
  pep425,
}: let
  l = builtins // lib;
  getSource = artifacts: let
    maybeWheels = l.partition (x: l.hasSuffix ".whl" x.file) (l.map (a: {
        file = a.url;
        inherit (a) hash algorithm;
      })
      artifacts);
    wheels = maybeWheels.right;
    sdists = maybeWheels.wrong;
    candidates = pep425.selectWheel wheels;
  in
    assert l.length sdists == 1;
      if l.length candidates == 1
      then l.head candidates
      else l.head sdists;

  withExtra = environ: extra:
    environ
    // {
      extra = {
        type = "string";
        value = extra;
      };
    };

  mkPackage = environ: extras: entry: let
    extras' = [""] ++ extras;
    allRequirements = l.map pep508.parseString entry.requires_dists;
    allRequirementsByExtra =
      l.genAttrs
      extras'
      (extra:
        l.filter
        (dep:
          dep.markers
          == null
          || pep508.evalMarkers (withExtra environ extra)
          dep.markers)
        allRequirements);
    requirements' = l.unique (l.flatten (l.map (e: allRequirementsByExtra.${e}) extras'));
  in {
    name = entry.project_name;
    version = entry.version;
    source = getSource entry.artifacts;
    requirements = l.map (r: pypa.normalizePackageName r.name) requirements';
  };

  entriesFromLockField = lockField:
    l.listToAttrs
    (l.map
      (e: l.nameValuePair (pypa.normalizePackageName e.project_name) e)
      (l.flatten
        (l.map (v: v.locked_requirements) lockField.locked_resolves)));

  packagesFromLockField = environ: extras: lockField:
    l.mapAttrs (_: mkPackage environ extras)
    (entriesFromLockField lockField);
in {
  inherit
    getSource
    mkPackage
    withExtra
    entriesFromLockField
    packagesFromLockField
    ;
}
