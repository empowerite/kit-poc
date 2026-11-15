# model.jq - the model of kit's entities, merged from its files (jq module)
# ----------------------------------------------------------------------------------------------------------------------
# import "model" as model; with jq -L "${kit_jq}". It holds one section for each concern, in the order a run takes them:
#
#   merge   build turns the document model:load prints into one model, {domains, entities, findings}, and holds the
#           repository's additions to the narrowing the release allows.
#   check   check gives the findings of a built model, the merge's first, and stubs the names of its stub entities.
#
# build is given {"files": [{domain, origin, path, doc}]}, the release's files first, then the repository's. A file
# named domain.yml is a domain's, and any other holds an entity (entity:) or an addition to one (extends:). An entity
# is {domain, origin, layer, tool, over, means, stub, sum, variants, fields, relations}, the keys its file set, with
# the domain and origin of the file that defines it. A finding is one sentence that names the entity and the file.
#
# see: modules/bash/model.sh, docs/model.md, docs/superpowers/specs/2026-11-15-entity-model-design.md

# ----------------------------------------------------------------------------------------------------------------------
# merge
# ----------------------------------------------------------------------------------------------------------------------

# entity_keys are the keys of an entity file that go into the entity.
def entity_keys: ["layer", "tool", "over", "means", "stub", "sum", "variants", "fields", "relations"];

# owned_keys are the keys only the file that defines an entity sets: an extension sets none of them.
def owned_keys: ["layer", "tool", "over", "stub", "sum", "means", "variants"];

# arity_holds is the table of arities: each holds itself and the narrower ones. many holds some, option, and one; some and
# option hold one. Its keys are the arities there are.
def arity_holds: {many: ["many", "some", "option", "one"], some: ["some", "one"], option: ["option", "one"], one: ["one"]};

# narrows($old; $new) is true when an arity $new is $old or narrower. An arity not written is one.
def narrows($old; $new):
  (arity_holds[$old // "one"] // []) as $held
  | any($held[]; . == ($new // "one"));

# enum_subset($old; $new) is true when both types are {enum: [..]} and the new values are among the old.
def enum_subset($old; $new):
  ($old | type) == "object" and ($new | type) == "object" and ($old.enum | type) == "array"
  and ($new.enum | type) == "array" and ($new.enum - $old.enum == []);

# refine($group; $label; $path; $new) is the member {value, findings} an extension leaves: the input member with the
# arity (or, for a field, the enum subset) the extension narrows to. $group is "fields" or "relations", $label is
# Entity.name, and any other key, or a widening, is a finding.
def refine($group; $label; $path; $new):
  . as $old
  | reduce ($new | keys_unsorted[]) as $k ({value: $old, findings: []};
      if $k == "arity" then
        if ($new.arity | type) != "string" then
          .findings += ["\($path) sets the arity of \($label) to something that is not a string, and an extension may"
            + " only narrow it"]
        elif narrows($old.arity; $new.arity) then .value.arity = $new.arity
        else .findings += ["\($path) changes the arity of \($label) from \($old.arity // "one") to \($new.arity), which"
          + " does not narrow it"] end
      elif $k == "type" and $group == "fields" then
        if $new.type == $old.type or enum_subset($old.type; $new.type) then .value.type = $new.type
        else .findings += ["\($path) changes the type of \($label), which an extension may only narrow to a subset of an"
          + " enum"] end
      elif $k == "to" and $group == "relations" then
        if $new.to == $old.to then .
        else .findings += ["\($path) changes the to of \($label), which an extension may not change"] end
      else
        .findings += ["\($path) sets \($k) on \($label), which an extension may not change; it may set only "
          + (if $group == "fields" then "arity and an enum subset" else "arity" end)]
      end);

# sound($doc; $group; $name; $path) is {members, findings} for the fields or relations ($group) of a file's document: the
# members that are mappings of keys, and a finding for each that is not, and for a $group that is not a mapping. $name is
# the entity. members is null when the file does not give $group, or gives it as something that is not a mapping.
def sound($doc; $group; $name; $path):
  if ($doc | has($group)) | not then {members: null, findings: []}
  elif ($doc[$group] | type) != "object" then
    {members: null, findings: ["\($path) gives \($group) on \($name) as something that is not a mapping"]}
  else
    {members: ($doc[$group] | with_entries(select(.value | type == "object"))),
     findings: [$doc[$group] | to_entries[] | select(.value | type != "object")
       | "\($path) gives \($name).\(.key) as something that is not a mapping of keys"]}
  end;

# define($files) is {entities, paths, findings}: each entity file's entity, the first definition of a name standing,
# and a later one a finding. paths holds the path of the file that defines each entity.
def define($files):
  reduce $files[] as $f ({entities: {}, paths: {}, findings: []};
    $f.doc.entity as $name
    | if .entities[$name] != null then
        .findings += ["\($name) is defined twice (\(.paths[$name]), \($f.path))"]
      else
        (reduce ("fields", "relations") as $group ({entity: ({domain: $f.domain, origin: $f.origin}
            + ($f.doc | with_entries(select(.key | IN(entity_keys[]) and (IN("fields", "relations") | not))))),
            findings: []};
          sound($f.doc; $group; $name; $f.path) as $s
          | .findings += $s.findings
          | if $s.members != null then .entity[$group] = $s.members else . end)) as $built
        | .entities[$name] = $built.entity
        | .findings += $built.findings
        | .paths[$name] = $f.path
      end);

# extend($f) is the model {entities, findings} with the extends file $f applied: the fields and relations it adds, the
# arities and enums it narrows, and a finding for all else.
def extend($f):
  $f.doc.extends as $name
  | if .entities[$name] == null then .findings += ["\($f.path) extends \($name), which no file defines"]
    else
      reduce (owned_keys[] | select(. as $k | $f.doc | has($k))) as $k (.;
        .findings += ["\($f.path) sets \($k) on \($name), which it extends and does not define; \($k) is the defining"
          + " file\u0027s to set"])
      | reduce ("fields", "relations") as $group (.;
          sound($f.doc; $group; $name; $f.path) as $s
          | .findings += $s.findings
          | reduce (($s.members // {}) | keys_unsorted[]) as $m (.;
              "\($name).\($m)" as $label
              | if .entities[$name][$group][$m] == null then .entities[$name][$group][$m] = $s.members[$m]
                else
                  (.entities[$name][$group][$m] | refine($group; $label; $f.path; $s.members[$m])) as $r
                  | .entities[$name][$group][$m] = $r.value
                  | .findings += $r.findings
                end))
    end;

# build gives the model of a document: {domains, entities, findings}. Every file that defines an entity is applied before
# any that extends one, so an extension may extend an entity a file of the repository defines.
def build:
  [.files[] | select(.path | split("/") | last == "domain.yml")] as $domain_files
  | [.files[] | select((.path | split("/") | last) != "domain.yml")] as $files
  | [$files[] | select((.doc | type) == "object" and (.doc.entity | type) == "string" and .doc.extends == null)] as $entity_files
  | [$files[] | select((.doc | type) == "object" and .doc.entity == null and (.doc.extends | type) == "string")] as $extend_files
  | ([$files[] | select(((.doc | type) == "object" and (.doc.entity != null or .doc.extends != null)) | not)
      | "\(.path) names neither an entity nor an extension"]
    + [$files[] | select((.doc | type) == "object" and .doc.entity != null and .doc.extends != null)
      | "\(.path) names both an entity and an extension"]
    + [$files[] | select((.doc | type) == "object" and .doc.extends == null and .doc.entity != null
        and (.doc.entity | type) != "string")
      | "\(.path) gives entity as something that is not a string"]
    + [$files[] | select((.doc | type) == "object" and .doc.entity == null and .doc.extends != null
        and (.doc.extends | type) != "string")
      | "\(.path) gives extends as something that is not a string"]) as $unnamed
  | define($entity_files) as $defined
  | reduce $extend_files[] as $f ({entities: $defined.entities, findings: $defined.findings}; extend($f))
  | .findings += $unnamed
  | {domains: ([$domain_files[] | {key: .domain, value: (.doc | with_entries(select(.key | IN("name", "intro", "layout"))))}]
        | from_entries),
      entities, findings};

# ----------------------------------------------------------------------------------------------------------------------
# check
# ----------------------------------------------------------------------------------------------------------------------

# scalar_types are the types that need no entity.
def scalar_types: ["Text", "Int", "Bool", "Bytes", "Path", "Url", "Time", "Hash"];

# show is a value as a finding writes it: a string as it is, anything else as JSON.
def show: if type == "string" then . else tojson end;

# sentence is true for a string with something in it.
def sentence: type == "string" and . != "";

# entity_named($model) is true when the string is the name of an entity of the model.
def entity_named($model): . as $name | type == "string" and ($model.entities | has($name));

# type_known($model) is true for a scalar, an {enum: [..]}, and the name of an entity.
def type_known($model):
  if type == "string" then IN(scalar_types[]) or entity_named($model)
  elif type == "object" then (.enum | type) == "array" and (.enum | length) > 0 and all(.enum[]; type == "string")
  else false end;

# arity_findings($label) is a finding when a field or relation sets an arity that is not in the arity table.
def arity_findings($label):
  if has("arity") then
    .arity as $a
    | if ($a | type) == "string" and (arity_holds | has($a)) then empty
      else "\($label) has arity \($a | show), which is not one, option, many, or some" end
  else empty end;

# field_findings($model; $label) are the findings of one field: its type, arity, source, status, and what a held or a
# derived field must say.
def field_findings($model; $label):
  (if (.type | type_known($model)) then empty
    else "\($label) has type \(.type | show), which is not a scalar, an enum, or an entity" end),
  arity_findings($label),
  (if has("source") and (.source | IN("stored", "derived") | not)
    then "\($label) has source \(.source | show), which is not stored or derived" else empty end),
  (if has("status") and (.status | IN("held", "planned", "unused") | not)
    then "\($label) has status \(.status | show), which is not held, planned, or unused" else empty end),
  (if .status == "held" and ((."read-by" | sentence) | not) then "\($label) is held and has no read-by" else empty end),
  (if .source == "derived" and ((.from | sentence) | not) then "\($label) is derived and has no from" else empty end);

# inverse_findings($model; $entity; $label) are the findings of the inverse a relation names: it is written
# Entity.relation, exists, names this relation back, and sits on the entity this relation goes to. The inverse's own
# target is the entity of its own check, which names the same pair from the other side.
def inverse_findings($model; $entity; $label):
  . as $r
  | (.inverse | if type == "string" then split(".") else [] end) as $parts
  | if ($parts | length) != 2 or ($parts | any(. == "")) then
      "\($label) has inverse \(.inverse | show), which is not written Entity.relation"
    else
      $parts[0] as $target
      | $model.entities[$target].relations[$parts[1]] as $other
      | if $other == null then "\($label) names inverse \(.inverse), which does not exist"
        else
          (if $other.inverse != $label then "\($label) names inverse \(.inverse), which does not name \($label) back"
            else empty end),
          (if ($r.to | entity_named($model)) and $r.to != $target then
              if .inverse == $label then
                "\($label) is its own inverse and goes to \($r.to), not \($entity); only a relation to its own entity can"
                + " be its own inverse"
              else "\($label) goes to \($r.to), but its inverse \(.inverse) is on \($target)" end
            else empty end)
        end
    end;

# reach_findings($model; $entity; $label) are the findings of a relation into a sum: each entity a variant holds must have
# a relation back to $entity, derived or with an inverse.
def reach_findings($model; $entity; $label):
  .to as $sum
  | if ($sum | entity_named($model)) and $model.entities[$sum].sum == true then
      [($model.entities[$sum].variants | if type == "object" then .[] else empty end)
        | select(type == "object") | .[] | select(entity_named($model))] | unique[] as $held
      | if any(($model.entities[$held].relations // {})[]; .to == $entity) then empty
        else "\($label) reaches \($held) through \($sum), and \($held) has no relation back to \($entity)" end
    else empty end;

# relation_findings($model; $entity; $name) are the findings of one relation: its to, arity, ordered, and its inverse or
# derivation.
def relation_findings($model; $entity; $name):
  "\($entity).\($name)" as $label
  | (if (.to | entity_named($model)) then empty
    else "\($label) goes to \(.to | show), which is not an entity" end),
  arity_findings($label),
  (if has("ordered") then
      if (.ordered | type) != "boolean" then "\($label) has ordered \(.ordered | show), which is not true or false"
      elif (has("arity") | not) or (.arity | IN("one", "option")) then
        "\($label) sets ordered on arity \(.arity // "one"), which is not many or some"
      else empty end
    else empty end),
  (if .inverse != null and .derived != null then "\($label) has both an inverse and a derived; it has one"
    elif .inverse == null and .derived == null then "\($label) has neither an inverse nor a derived; it has one"
    elif .derived != null then
      if (.derived | sentence) then empty else "\($label) gives derived as something that is not a sentence" end
    else inverse_findings($model; $entity; $label) end),
  reach_findings($model; $entity; $label);

# kind_findings($name) are the findings of the keys that say what an entity is: its layer, which only a stub may leave
# out, and tool, and sum and stub, which are true or false.
def kind_findings($name):
  (if has("layer") | not then (if .stub == true then empty else "\($name) has no layer" end) else empty end),
  (if has("layer") and (.layer | IN("native", "logical") | not)
      then "\($name) has layer \(.layer | show), which is not native or logical" else empty end),
  (if .layer == "native" and ((.tool | sentence) | not) then "\($name) is native and names no tool"
    elif .layer == "logical" and .tool != null
      then "\($name) is logical and names a tool, \(.tool | show); only a native entity has one" else empty end),
  (("sum", "stub") as $k
    | if has($k) and (.[$k] | type) != "boolean"
      then "\($name) has \($k) \(.[$k] | show), which is not true or false" else empty end);

# variant_findings($model; $name) are the findings of an entity's variants: a sum has a non-empty mapping of them, each a
# mapping of field to the entity it holds, and an entity that is not a sum has none.
def variant_findings($model; $name):
  if .sum != true then
    if has("variants") then "\($name) has variants and is not a sum" else empty end
  elif (has("variants") | not) or .variants == {} or .variants == [] or .variants == null
    then "\($name) is a sum and has no variants"
  elif (.variants | type) != "object" then "\($name) gives variants as something that is not a mapping"
  else
    .variants | to_entries | sort_by(.key)[]
    | .key as $variant
    | if (.value | type) != "object" then "\($name) variant \($variant) is not a mapping of field to entity"
      else .value | to_entries | sort_by(.key)[]
        | select(.value | entity_named($model) | not)
        | "\($name) variant \($variant) field \(.key) names \(.value | show), which is not an entity"
      end
  end;

# entity_findings($model; $name) are the findings of one entity: a stub with fields, its kind, its variants, then its
# fields and its relations, each by name.
def entity_findings($model; $name):
  $model.entities[$name] as $entity
  | (if $entity.stub == true and (($entity.fields // {}) | length) > 0
      then "\($name) is a stub and has fields: \($entity.fields | keys | join(", "))" else empty end),
    ($entity | kind_findings($name)),
    ($entity | variant_findings($model; $name)),
    (($entity.fields // {}) | . as $fields | keys[] as $f | $fields[$f] | field_findings($model; "\($name).\($f)")),
    (($entity.relations // {}) | . as $relations | keys[] as $r | $relations[$r] | relation_findings($model; $name; $r));

# check gives the findings of a built model, as an array of sentences: the merge's, then the entities' by name. Empty
# when the model holds.
def check:
  . as $model
  | $model.findings + [$model.entities | keys[] | entity_findings($model; .)];

# stubs gives the names of the stub entities of a built model, sorted.
def stubs: [.entities | to_entries[] | select(.value.stub == true) | .key] | sort;

# ----------------------------------------------------------------------------------------------------------------------
# tables
# ----------------------------------------------------------------------------------------------------------------------

# arity_text is the arity of a field or a relation as a range: 1, 0..1, 0..*, or 1..*. An arity not given is one.
def arity_text: ({one: "1", option: "0..1", many: "0..*", some: "1..*"})[. // "one"];

# cell is a value as the text of a table cell: nothing is empty, a newline is a space, and a | is written \|.
def cell:
  (. // "") | (if type == "string" then . else tojson end) | sub("\n+$"; "") | gsub("\n"; " ") | gsub("\\|"; "\\|");

# row is the cells of an array as one line of a table.
def row: "| " + (map(cell) | join(" | ")) + " |";

# table is a header and its rows, as the lines of a table.
def table($header; $rows): [($header | row), ($header | map("---") | row)] + $rows;

# type_text is a type as it is written in a table: a name as it is, an enum as enum(a, b, c).
def type_text:
  if type == "object" and (.enum | type) == "array" then "enum(\(.enum | map(show) | join(", ")))" else show end;

# field_row is the row of a field: its type, arity, source, status, what reads it, and what it means.
def field_row($name):
  [$name, (.type | type_text), (.arity | arity_text), (.source // "stored"), .status, .["read-by"],
    (if .source == "derived" then "derived from \(.from // ""). \(.means // "")" | sub(" $"; "") else .means end)];

# fields gives the table of an entity of a built model, given its name: its fields by name; for a sum, its variants and
# their fields; for a stub, the one line that says it is one. A table is lines joined with newlines.
def fields($name):
  .entities[$name] as $entity
  | if $entity.stub == true then "_\($name) is a stub: named, not yet unpacked._"
    elif $entity.sum == true then
      table(["Variant", "Field", "Type"];
        [($entity.variants // {}) | to_entries | sort_by(.key)[] | .key as $v
          | .value | to_entries | sort_by(.key)[] | [$v, .key, (.value | type_text)] | row]) | join("\n")
    else
      table(["Field", "Type", "Arity", "Source", "Status", "Read by", "Means"];
        [($entity.fields // {}) | to_entries | sort_by(.key)[] | .key as $f | .value | field_row($f) | row]) | join("\n")
    end;

# relation_row is the row of a relation: where it goes, its arity, whether it is ordered, its inverse, and what it means.
def relation_row($name):
  [$name, .to, (.arity | arity_text), (if .ordered == true then "ordered" else "" end),
    (if .derived != null then "derived" else .inverse end),
    (if .derived != null then "derived: \(.derived)" + (if (.means // "") == "" then "" else ". \(.means)" end) else .means end)];

# relations gives the table of the relations of a built model's domain, given its name: those of every entity in it, by
# entity then relation. A table is lines joined with newlines.
def relations($domain):
  table(["Relation", "To", "Arity", "Ordered", "Inverse", "Means"];
    [.entities | to_entries | sort_by(.key)[] | select(.value.domain == $domain) | .key as $e
      | (.value.relations // {}) | to_entries | sort_by(.key)[] | .key as $r | .value | relation_row("\($e).\($r)") | row])
  | join("\n");
