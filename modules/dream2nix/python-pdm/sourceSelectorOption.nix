{lib}:
lib.mkOption {
  type = lib.types.functionTo lib.types.str;
  description = ''
    A selector function which picks a source for a specific dependency
    Python dependencies can have multiple possible sources, like for example:
      - requests-2.31.0.tar.gz
      - requests-2.31.0-py3-none-any.whl
    The selector receives a list of possible sources and should return either a single source or null.
  '';
  example = lib.literalExpression ''
    fnames: lib.findFirst (fname: lib.hasSuffix "none-any.whl") none fnames
  '';
}
