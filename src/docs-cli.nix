{
  dream2nixDocsSrc,
  writeScriptBin,
  glow,
  ripgrep,
}:
writeScriptBin "d2n-docs" ''
  # convert to lowercase, all of our doc paths are in lowercase
  __docToShow="''${1,,}"
  # remove .md suffix if it exists, we add this later ourselves
  # doing this we can allow both "path" and "path.md"
  _docToShow="''${__docToShow%".md"}"
  # replace dots with slashes so "subsystems.name" can be used to access doc
  docToShow="''${_docToShow//./\/}"
  docs="${dream2nixDocsSrc}"

  function showDoc {
    ${glow}/bin/glow -lp "$docs/''${1}''${docToShow}.md"
  }
  function docExists {
    test -f "$docs/''${1}''${docToShow}.md"
  }

  # if no doc to show was passed then list available docs
  if [[ "$docToShow" == "" ]]; then
    echo "available documentation:''\n"
    cd $docs
    ${ripgrep}/bin/rg --files --sort=path
  # first we check for the doc in subsystems
  elif $(docExists "subsystems/"); then
    showDoc "subsystems/"
  # then we check in intro
  elif $(docExists "intro/"); then
    showDoc "intro/"
  # then in the root documentation directory
  # this also allows for any arbitrary doc path to be accessed
  elif $(docExists ""); then
    showDoc ""
  else
    echo "no documentation for '$docToShow'"
    echo "suggestions:''\n"
    cd $docs
    ${ripgrep}/bin/rg --files-with-matches \
      --sort=path "$docToShow"
  fi
''
