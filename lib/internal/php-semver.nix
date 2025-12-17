{lib, ...}: let
  l = lib // builtins;

  # Replace a list entry at defined index with set value
  ireplace = idx: value: list:
    l.genList (i:
      if i == idx
      then value
      else (l.elemAt list i)) (l.length list);

  orBlank = x:
    if x != null
    then x
    else "";

  operators = let
    mkComparison = ret: version: v:
      builtins.compareVersions version v == ret;

    mkCaretComparison = version: v: let
      ver = builtins.splitVersion v;
      major = l.toInt (l.head ver);
      upper = builtins.toString (l.toInt (l.head ver) + 1);
    in
      if major == 0
      then mkTildeComparison version v
      else operators.">=" version v && operators."<" version upper;

    mkTildeComparison = version: v: let
      ver = builtins.splitVersion v;
      len = l.length ver;
      truncated =
        if len > 1
        then l.init ver
        else ver;
      idx = (l.length truncated) - 1;
      minor = l.toString (l.toInt (l.elemAt truncated idx) + 1);
      upper = l.concatStringsSep "." (ireplace idx minor truncated);
    in
      operators.">=" version v && operators."<" version upper;
  in {
    # Prefix operators
    "==" = mkComparison 0;
    ">" = mkComparison 1;
    "<" = mkComparison (-1);
    "!=" = v: c: !operators."==" v c;
    ">=" = v: c: operators."==" v c || operators.">" v c;
    "<=" = v: c: operators."==" v c || operators."<" v c;
    # Semver specific operators
    "~" = mkTildeComparison;
    "^" = mkCaretComparison;
  };

  re = {
    operators = "([=><!~^]+)";
    version = "((0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)|(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)|(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)|(0|[1-9][0-9]*))?(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\\+([0-9a-zA-Z-]+(\\.[0-9a-zA-Z-]+)*))?";
  };

  reLengths = {
    operators = 1;
    version = 16;
  };

  parseConstraint = constraintStr: let
    # The common prefix operators
    mPre = l.match "${re.operators} *${re.version}" constraintStr;
    # There is an upper bound to the operator (this implementation is a bit hacky)
    mUpperBound =
      l.match "${re.operators} *${re.version} *< *${re.version}" constraintStr;
    # There is also an infix operator to match ranges
    mIn = l.match "${re.version} - *${re.version}" constraintStr;
    # There is no operators
    mNone = l.match "${re.version}" constraintStr;
  in if mPre != null
    then {
      ops.t = l.elemAt mPre 0;
      v = orBlank (l.elemAt mPre reLengths.operators);
    }
    # Infix operators are range matches
    else if mIn != null
    then {
      ops = {
        t = "-";
        l = ">=";
        u = "<=";
      };
      v = {
        vl = orBlank (l.elemAt mIn 0);
        vu = orBlank (l.elemAt mIn reLengths.version);
      };
    }
    else if mUpperBound != null
    then {
      ops = {
        t = "-";
        l = l.elemAt mUpperBound 0;
        u = "<";
      };
      v = {
        vl = orBlank (l.elemAt mUpperBound reLengths.operators);
        vu = orBlank (l.elemAt mUpperBound (reLengths.operators + reLengths.version));
      };
    }
    else if mNone != null
    then {
      ops.t = "==";
      v = orBlank (l.elemAt mNone 0);
    }
    else throw ''Constraint "${constraintStr}" could not be parsed'';

  satisfiesSingleInternal = version: constraint: let
    inherit (parseConstraint constraint) ops v;
  in
    if ops.t == "-"
    then (operators."${ops.l}" version v.vl && operators."${ops.u}" version v.vu)
    else operators."${ops.t}" version v;

  # remove v from version strings: ^v1.2.3 -> ^1.2.3
  # remove branch suffix: ^1.2.x-dev -> ^1.2
  satisfiesSingle = version: constraint: let
    removeStability = c: let
      m = l.match "^(.*)[@][[:alpha:]]+$" c;
    in
      if m != null && l.length m >= 0
      then l.head m
      else c;
    removeSuffix = c: let
      m = l.match "^(.*)[-][[:alpha:]]+$" c;
    in
      if m != null && l.length m >= 0
      then l.head m
      else c;
    wildcard = c: let
      m = l.match "^([[:d:]]+.*)[.][*x]$" c;
    in
      if m != null && l.length m >= 0
      then "~${l.head m}.0"
      else c;
    removeV = c: let
      m = l.match "^(.)*v([[:d:]]+[.].*)$" c;
    in
      if m != null && l.length m > 0
      then l.concatStrings m
      else c;
    isVersionLike = c: let
      m = l.match "^([0-9><=!-^~*]*)$" c;
    in
      m != null && l.length m > 0;
    cleanConstraint = removeV (wildcard (removeSuffix (removeStability (l.removePrefix "dev-" constraint))));
    cleanVersion = l.removePrefix "v" (wildcard (removeSuffix version));
  in
    (l.elem (removeStability constraint) ["" "*"])
    || (version == constraint)
    || ((isVersionLike cleanConstraint) && (satisfiesSingleInternal cleanVersion cleanConstraint));

  trim = s: l.head (l.match "^[[:space:]]*(.*[^[:space:]])[[:space:]]*$" s);
  splitAlternatives = v: let
    # handle version alternatives: ^1.2 || ^2.0
    clean = l.replaceStrings ["||"] ["|"] v;
  in
    map trim (l.splitString "|" clean);
  splitConjunctives = v: let
    clean =
      l.replaceStrings
      ["," " - " " -" "- " " as "]
      [" " "-" "-" "-" "##"]
      v;
    cleanInlineAlias = v: let
      m = l.match "^(.*)[#][#](.*)$" v;
    in
      if m != null && l.length m > 0
      then l.head m
      else v;
  in
    map
    (x: trim (cleanInlineAlias x))
    (l.filter (x: x != "") (l.splitString " " clean));
in rec {
  # matching a version with semver
  # 1.0.2 (~1.0.1 || >=2.1 <2.4)
  satisfies = version: constraint:
    l.any
    (c:
      l.all
      (satisfiesSingle version)
      (splitConjunctives c))
    (splitAlternatives constraint);

  # matching multiversion like the one in `provide` with semver
  # (1.0|2.0) (^2.0 || 3.2 - 3.6)
  multiSatisfies = multiversion: constraint:
    l.any
    (version: satisfies version constraint)
    (splitAlternatives multiversion);
}
