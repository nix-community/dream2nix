{
  lib,
  ...
}:
rec {
  basename = path: lib.last (lib.splitString "/" path);

  dirname = path: builtins.concatStringsSep "/" (lib.init (lib.splitString "/" path));

  isFile = path: (builtins.readDir (dirname path))."${basename path}" ==  "regular";

  isDir = path: (builtins.readDir (dirname path))."${basename path}" ==  "directory";

  listFiles = path: lib.filterAttrs (n: v: v == "regular") (builtins.listDir path);

  matchTopLevelFiles = pattern: path:
    # is dir
    if isDir path then
      builtins.all (f: matchTopLevelFiles pattern f) (listFiles path)
    
    # is file
    else
      let
        match = (builtins.match pattern path);
      in
        if match == null then false else builtins.any (m: m != null) match;
  
  compatibleTopLevelPaths = pattern: paths:
    lib.filter
      (path:
        matchTopLevelFiles
          pattern
          path
      )
      paths;

  # allow a function to receive its input from an environment variable
  # whenever an empty set is passed
  makeCallableViaEnv = func: args:
    if args == {} then
      func (builtins.fromJSON (builtins.readFile (builtins.getEnv "FUNC_ARGS")))
    else
      func args;

}
