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

  # Need to account for the case where inside a quoted string will be a \"
  # cannot ignore backspace char inside quotes
  quotedIdentifier =
    let validChar = c: c != ''"'';
    in listLexeme (quotes (takeWhile1 validChar));

  identifier =
    let validChar = c: match ''[a-zA-Z0-9:@_-]'' c != null;
    in listLexeme (takeWhile1 validChar);

  atom = alt identifier quotedIdentifier;
  list = parens (many (listLexeme (alt atom list)));

  sexpr = alt atom list;
  lisp = many (skipThen outsideList sexpr);

  # TODO: Make this recursive so that it removes empty arrays
  cleanValues = value:
    let item = head value;
    in
      if typeOf item != "list" then item else
        if length item == 0 then null else
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

  parseLispFile = path: runParser lisp (builtins.readFile path);

in {
  testLine = ''(test world "this is a \"test\" world")'';

  inherit parseLispFile;

  parseRacketInfo = path: listToAttrs
    (map racketInfoExtractor ((parseLispFile path).value));

  parseRacketPkgs = path: listToAttrs
    (map racketPkgsExtractor
      (builtins.elemAt ((parseLispFile path).value) 0));
}
