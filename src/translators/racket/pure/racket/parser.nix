# Example: parse a lisp file
#
# Load in nix repl and test, e.g.:
#
# A general purpose lisp parser that returns the list of parsed tokens
# nix-repl> parseLispFile ./info.rkt
#
# { type = "success"; value = ...; }
#
# A parser for info.rkt files
# nix-repl> parseRacketInfo ./info.rkt
#
# { build-deps = [ ... ]; etc. }
#
# A parser for racket catalog pkgs
# nix-repl> parseRacketPkgs ./pkgs-subset.rkt
#
# { "2d" = { ... }; etc. }

{ lib, nix-parsec }:

with nix-parsec.parsec;
with lib;

let
  inherit (nix-parsec) lexer;
  inherit (builtins) match tail head length map typeOf elemAt;

  # Cannot use '' here as it strips white space
  # TODO: Get reference for this
  spaceChar = " ";

  # Skip until a root list node
  outsideList = skipWhile (c: c != ''('');

  # Skip chars not essential to list comprehension
  listSpaces =
    skipWhile (c:
      c == spaceChar  ||
      c == "\t"       ||
      c == "'"        ||
      c == "."        ||
      c == "#"        ||
      c == ":"        ||
      c == "\n");

  listLexeme = lexer.lexeme listSpaces;

  quotes = between (string ''"'') (string ''"'');
  parens = between (string ''('') (string '')'');

  # TODO: Make this general
  # This accounts for the case where inside a quoted string will be a \"
  quotedIdentifier = ps:
    let
      str = elemAt ps 0;
      offset = elemAt ps 1;
      len = elemAt ps 2;
      strLen = stringLength str;
      # Search for the next offset that violates the predicate
      go = ix:
        if ix >= strLen || (substring ix 1 str) == ''"''
          then ix
        else if (substring ix 2 str) == ''\"''
          then go (ix + 2)
        else go (ix + 1);
      endIx = go offset;
      # The number of characters we found
      numChars = endIx - offset;
    in [(substring offset numChars str) endIx (len - numChars)];

  identifier =
    let validChar = c: match ''[a-zA-Z0-9+|:@_-]'' c != null;
    in listLexeme (takeWhile1 validChar);

  atom = alt identifier (quotes quotedIdentifier);
  list = parens (many (listLexeme (alt atom list)));

  sexpr = alt atom list;
  multi-lineSexpr = many (skipThen outsideList sexpr);

  # TODO: Make this recursive so that it removes empty arrays
  cleanValues = value:
    let item = head value;
    in
      if typeOf item != "list" then item else
        if length item == 0 then "" else
          if length item == 1 then head item else
            item;

  racketInfoExtractor = parsedLisp:
    let
      name = head (tail parsedLisp);
      value = tail (tail parsedLisp);
      value' = cleanValues value;
    in
      nameValuePair name value';

  racketPkgsExtractor = parsedLisp:
    let
      name = head parsedLisp;
      value = elemAt (tail (tail parsedLisp)) 0;
      value' = listToAttrs
        (map
          (list: nameValuePair (head list) (cleanValues (tail list))) value);
    in
      nameValuePair name value';

  parseLispFile = path: runParser multi-lineSexpr (builtins.readFile path);

in {
  inherit parseLispFile;

  parseRacketInfo = path: listToAttrs
    (map racketInfoExtractor ((parseLispFile path).value));

  # An Example of what NOT to do with nix-parsec
  # This is a very long single line S-expression
  # NOTE: it takes around 15 minutes to evaluate ./pkgs-all
  # (on a fairly powerful machine)
  parseRacketCatalog = path: listToAttrs
    (map racketPkgsExtractor
      (runParser (skipThen outsideList sexpr) (builtins.readFile path)).value);

}
