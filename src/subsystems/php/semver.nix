{lib}: let
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
      minor = builtins.toString (l.toInt (l.head ver) + 1);
      upper = builtins.concatStringsSep "." (ireplace 0 minor ver);
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
    version = "((0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)|(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)|(0|[1-9][0-9]*)){0,1}([.x*]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*)){0,1}(\\+([0-9a-zA-Z-]+(\\.[0-9a-zA-Z-]+)*)){0,1}";
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
  in (
    if mPre != null
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
    else throw ''Constraint "${constraintStr}" could not be parsed''
  );

  satisfies = version: constraint: let
    inherit (parseConstraint constraint) ops v;
  in
    if ops.t == "-"
    then (operators."${ops.l}" version v.vl && operators."${ops.u}" version v.vu)
    else operators."${ops.t}" version v;
in {
  inherit satisfies;
}
