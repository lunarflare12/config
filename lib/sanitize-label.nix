lib: text:
  lib.concatStrings (map (char:
    if builtins.match "[a-zA-Z0-9:_.-]" char != null then char else "_"
  ) (lib.stringToCharacters text))
