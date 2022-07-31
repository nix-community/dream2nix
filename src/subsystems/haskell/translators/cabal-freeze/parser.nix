{
  dlib,
  lib,
}: cabalFreezeFile: let
  l = lib // builtins;

  cabalFreezeFileText = dlib.readTextFile cabalFreezeFile;

  sectionNamesAndContents = l.tail (l.split "\n([^ \t:]+):" (
    "\n" + (trimSurroundingWhitespace cabalFreezeFileText)
  ));

  sectionNames = l.pipe sectionNamesAndContents [
    (l.filter l.isList)
    (l.map l.head)
  ];

  sectionContents = l.pipe sectionNamesAndContents [
    (l.filter l.isString)
    (l.map
      (str:
        l.pipe str [
          (l.splitString "\n")
          l.concatStrings
          (l.splitString ",")
          (l.map trimSurroundingWhitespace)
        ]))
  ];

  trimSurroundingWhitespace = str:
    l.pipe str [
      (l.split "^[[:space:]]*")
      l.flatten
      l.concatStrings
      (l.split "[[:space:]]*$")
      l.flatten
      l.concatStrings
    ];

  sectionNamesWithContents = l.listToAttrs (l.zipListsWith l.nameValuePair sectionNames sectionContents);

  cabalPackageNameVersionRegexp = "any\.([a-zA-Z0-9_-]+) ==([^, \t]+)";

  partitionedConstraints = l.partition (str: l.match cabalPackageNameVersionRegexp str != null) sectionNamesWithContents.constraints;
in {
  packagesAndVersionsList =
    l.map
    (str:
      l.pipe str
      [
        (l.match cabalPackageNameVersionRegexp)
        (packageAndVersion: dlib.nameVersionPair (l.head packageAndVersion) (l.last packageAndVersion))
      ])
    partitionedConstraints.right;

  packagesAndVersionsAttrSet =
    l.pipe
    partitionedConstraints.right
    [
      (l.map
        (str:
          l.pipe str
          [
            (l.match cabalPackageNameVersionRegexp)
            (packageAndVersion: l.nameValuePair (l.head packageAndVersion) (l.last packageAndVersion))
          ]))
      l.listToAttrs
    ];

  cabalFlags = l.pipe partitionedConstraints.wrong [
    (l.map (l.splitString " "))
    (
      l.map
      (words: let
        packageName = l.head words;
        configureFlags = l.pipe words [
          l.tail
          (l.map (s: let
            matchList = l.match "([+-])(.+)" s;
            polarity = l.head matchList;
            flagName = l.last matchList;
          in
            "-f"
            + (
              l.optionalString (polarity == "-") "-"
            )
            + flagName))
        ];
      in
        l.nameValuePair packageName configureFlags)
    )
    l.listToAttrs
  ];

  # TODO: maybe use the index-state?
}
