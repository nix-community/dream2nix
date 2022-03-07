{lib}: let
  inherit
    (lib)
    length
    elemAt
    concatMap
    all
    concatLists
    concatStringsSep
    concatMapStringsSep
    mapAttrsToList
    ;

  inherit
    (builtins)
    abort
    match
    toJSON
    typeOf
    ;

  quoteKey = k:
    if match "[a-zA-Z]+" k == []
    then k
    else quoteString k;

  quoteString = builtins.toJSON;

  outputValInner = v: let
    ty = tomlTy v;
  in
    if ty == "set"
    then let
      vals =
        mapAttrsToList
        (k': v': "${quoteKey k'} = ${outputValInner v'}")
        v;
      valsStr = concatStringsSep ", " vals;
    in "{ ${valsStr} }"
    else outputVal v;

  outputVal = v: let
    ty = tomlTy v;
  in
    if (ty == "bool" || ty == "int")
    then builtins.toJSON v
    else if ty == "string"
    then quoteString v
    else if ty == "list" || ty == "list_of_attrs"
    then let
      vals = map quoteString v;
      valsStr = concatStringsSep ", " vals;
    in "[ ${valsStr} ]"
    else if ty == "set"
    then abort "unsupported set for not-inner value"
    else abort "Not implemented: type ${ty}";

  outputKeyValInner = k: v: let
    ty = tomlTy v;
  in
    if ty == "set"
    then let
      vals =
        mapAttrsToList
        (k': v': "${quoteKey k'} = ${outputValInner v'}")
        v;
      valsStr = concatStringsSep ", " vals;
    in ["${quoteKey k} = { ${valsStr} }"]
    else outputKeyVal k v;

  # Returns a list of strings; one string per line
  outputKeyVal = k: v: let
    ty = tomlTy v;
  in
    if ty == "bool" || ty == "int"
    then ["${quoteKey k} = ${outputValInner v}"]
    else if ty == "string"
    then ["${quoteKey k} = ${quoteString v}"]
    else if ty == "list_of_attrs"
    then
      concatMap (
        inner:
          ["[[${k}]]"] ++ (concatLists (mapAttrsToList outputKeyValInner inner))
      )
      v
    else if ty == "list"
    then let
      vals = map quoteString v;
      valsStr = concatStringsSep ", " vals;
    in ["${quoteKey k} = [ ${valsStr} ]"]
    else if ty == "set"
    then ["[${k}]"] ++ (concatLists (mapAttrsToList outputKeyValInner v))
    else abort "Not implemented: type ${ty} for key ${k}";

  tomlTy = x:
    if typeOf x == "string"
    then "string"
    else if typeOf x == "bool"
    then "bool"
    else if typeOf x == "int"
    then "int"
    else if typeOf x == "float"
    then "float"
    else if typeOf x == "set"
    then
      if lib.isDerivation x
      then "string"
      else "set"
    else if typeOf x == "list"
    then
      if length x == 0
      then "list"
      else let
        ty = typeOf (elemAt x 0);
      in
        #assert (all (v: typeOf v == ty) x);
        if ty == "set"
        then "list_of_attrs"
        else "list"
    else abort "Not implemented: toml type for ${typeOf x}";

  toTOML = attrs:
    assert (typeOf attrs == "set"); let
      byTy =
        lib.foldl
        (
          acc: x: let
            ty = tomlTy x.v;
          in
            acc // {"${ty}" = (acc.${ty} or []) ++ [x];}
        )
        {} (mapAttrsToList (k: v: {inherit k v;}) attrs);
    in
      concatMapStringsSep "\n"
      (kv: concatStringsSep "\n" (outputKeyVal kv.k kv.v))
      (
        (byTy.string or [])
        ++ (byTy.int or [])
        ++ (byTy.float or [])
        ++ (byTy.list or [])
        ++ (byTy.list_of_attrs or [])
        ++ (byTy.set or [])
      );
in
  toTOML
