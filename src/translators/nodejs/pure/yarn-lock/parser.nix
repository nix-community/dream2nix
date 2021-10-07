# Example: parse a yarn.lock file
#
# Load in nix repl and test, e.g.:
#
# nix-repl> parseConfigFile ./yarn.lock
# { type = "success"; value = ...; }

{ lib, nix-parsec }:

with nix-parsec.parsec;

rec {
  inherit (nix-parsec) parsec;

  # Skip spaces and line comments and newlines
  spaceComments = nix-parsec.lexer.space
    (skipWhile1 (c: c == " " || c == "\t" || c == "\n"))
    (nix-parsec.lexer.skipLineComment "#")
    fail;

  charInsideQuotes = c: c != "\"";
  charOutsideQuotes = c: c != "\"" && c != "\n" && c != " " && c != "," && c != ":";
  unquotedString = takeWhile1 charOutsideQuotes;
  newLine = string "\n";

  # use the nix-parsec quotedString
  quotedString = between (string "\"") (string "\"") (takeWhile1 charInsideQuotes);

  # TODO add the relevant fmap to add the attributes
  version = skipThen (string "  version ") (thenSkip quotedString newLine);
  # TODO instead of nextLine use an exact count of space and newline ?:w
  resolved = skipThen (string "  resolved ") (thenSkip quotedString newLine);
  integrity = skipThen (string "  integrity ") (thenSkip unquotedString newLine);

  dependencyList = thenSkip (sepBy singleDependency newLine) newLine;
  dependencies = skipThen (string "  dependencies:\n") dependencyList;
  optionalDependencies = skipThen (string "  optionalDependencies:\n") dependencyList;

  singleDependency = bind (skipThen (string "    ") (alt quotedString unquotedString)) (parsed_dependency:
    skipThen (string " ") (
      bind quotedString (parsed_version:
        pure { "${parsed_dependency}" = parsed_version; }
      )
    )
  );

  dependencyNames = thenSkip (sepBy (alt quotedString unquotedString) (string ", ")) (string ":\n");

  dependencyAttrs = bind version (parsedVersion:
    bind resolved (parsedResolved:
      bind (optional integrity) (parsedIntegrity:
        bind (optional dependencies) (parsedDependencies:
          bind (optional optionalDependencies) (parsedOptionalDependencies:
            pure (
              { version = parsedVersion; resolved = parsedResolved; }
              //
              (if parsedIntegrity == [ ] then { } else { integrity = builtins.head parsedIntegrity; })
              //
              (if parsedDependencies == [ ] then { } else { dependencies = builtins.head parsedDependencies; })
              //
              (if parsedOptionalDependencies == [ ] then { } else { optionalDependencies = builtins.head parsedOptionalDependencies; })
            )
          )))));
  namesToAttrsList = namesList: dependencyAttrs: map (dependencyName: lib.nameValuePair dependencyName dependencyAttrs) namesList;

  group =
    bind dependencyNames (namesList:
      fmap (parsedAttrs: builtins.listToAttrs (namesToAttrsList namesList parsedAttrs))
        dependencyAttrs);

  configFile =
    (skipThen spaceComments
      (thenSkip (sepBy group newLine) eof));

  parseLock = path: nix-parsec.parsec.runParser configFile (builtins.readFile path);
}
