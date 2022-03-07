{lib ? (import <nixpkgs> {}).lib, ...}: let
  l = lib // builtins;

  parse = text: let
    lines = l.splitString "\n" text;

    findStartLineNum = num: let
      line = l.elemAt lines num;
    in
      if
        ! l.hasPrefix "#" line
        && ! l.hasPrefix " " line
        && ! l.hasPrefix "_" line
      then num
      else findStartLineNum (num + 1);

    contentLines =
      l.sublist
      (findStartLineNum 0)
      ((l.length lines) - 1)
      lines;

    matchLine = line: let
      # yarn v2
      m1 = l.match ''( *)(.*): (.*)'' line;
      m2 = l.match ''( *)(.*):$'' line;

      # yarn v1
      m3 = l.match ''( *)(.*) "(.*)"'' line;
      m4 = l.match ''( *)(.*) (.*)'' line;
    in
      if m1 != null
      then {
        indent = (l.stringLength (l.elemAt m1 0)) / 2;
        key = l.elemAt m1 1;
        value = l.elemAt m1 2;
      }
      else if m2 != null
      then {
        indent = (l.stringLength (l.elemAt m2 0)) / 2;
        # transform yarn 1 to yarn 2 tyle
        key =
          l.replaceStrings ['', "''] ['', '']
          (l.replaceStrings [''", ''] ['', ''] (l.elemAt m2 1));
        value = null;
      }
      else if m3 != null
      then {
        indent = (l.stringLength (l.elemAt m3 0)) / 2;
        key = l.elemAt m3 1;
        value = l.elemAt m3 2;
      }
      else if m4 != null
      then {
        indent = (l.stringLength (l.elemAt m4 0)) / 2;
        key = l.elemAt m4 1;
        value = l.elemAt m4 2;
      }
      else null;

    closingParenthesis = num:
      if num == 1
      then "}"
      else "}" + (closingParenthesis (num - 1));

    jsonLines = lines: let
      filtered = l.filter (line: l.match ''[[:space:]]*'' line == null) lines;
      matched = l.map (line: matchLine line) filtered;
    in
      l.imap0
      (i: line: let
        mNext = l.elemAt matched (i + 1);
        m = l.elemAt matched i;
        keyParenthesis = let
          beginOK = l.hasPrefix ''"'' m.key;
          endOK = l.hasSuffix ''"'' m.key;
          begin = l.optionalString (! beginOK) ''"'';
          end = l.optionalString (! endOK) ''"'';
        in ''${begin}${m.key}${end}'';
        valParenthesis =
          if l.hasPrefix ''"'' m.value
          then m.value
          else ''"${m.value}"'';
      in
        if l.length filtered == i + 1
        then let
          end = closingParenthesis m.indent;
        in ''${keyParenthesis}: ${valParenthesis}${end}}''
        else if m.value == null
        then ''${keyParenthesis}: {''
        # if indent of next line is smaller, close the object
        else if mNext.indent < m.indent
        then let
          end = closingParenthesis (m.indent - mNext.indent);
        in ''${keyParenthesis}: ${valParenthesis}${end},''
        else ''${keyParenthesis}: ${valParenthesis},'')
      filtered;

    json = "{${l.concatStringsSep "\n" (jsonLines contentLines)}";

    dataRaw = l.fromJSON json;

    # transform key collections like:
    #   "@babel/code-frame@^7.0.0, @babel/code-frame@^7.10.4"
    # ... to individual entries
    data =
      l.listToAttrs
      (l.flatten
        (l.mapAttrsToList
          (n: v: let
            keys = l.splitString ", " n;
          in
            l.map (k: l.nameValuePair k v) keys)
          dataRaw));
  in
    data;
in {
  inherit parse;
}
