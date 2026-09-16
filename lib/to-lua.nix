{ lib }:

let
  toLua =
    value:
    if builtins.isAttrs value then
      "{ ${lib.concatStringsSep ", " (lib.mapAttrsToList (key: val: "${key} = ${toLua val}") value)} }"
    else if builtins.isList value then
      "{ ${lib.concatMapStringsSep ", " toLua value} }"
    else if builtins.isBool value then
      (if value then "true" else "false")
    else if builtins.isInt value || builtins.isFloat value then
      builtins.toJSON value
    else if builtins.isString value then
      "\"${lib.escape [ "\\" "\"" ] value}\""
    else if value == null then
      "nil"
    else
      throw "toLua: unsupported value";
in
toLua
