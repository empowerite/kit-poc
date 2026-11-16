# model.jq - the model of kit's entities, merged from its files (jq module)
# ----------------------------------------------------------------------------------------------------------------------
# import "model" as model; with jq -L "${kit_jq}". It holds one section for each concern, in the order a run takes them:
#
#   schema  the keys, names, and patterns of a model file and a domain.yml, read from their schemas.
#   merge   build turns the document model:load prints into one model, {domains, entities, extensions, findings}, and
#           holds the repository's additions to the narrowing the release allows.
#   check   check gives the findings of a built model, the merge's first, and stubs the names of its stub entities.
#   tables  fields and relations give the markdown tables of an entity's fields and of a domain's relations.
#   page    page gives the markdown body of a domain's page, made of those tables and the entities' sentences.
#
# build is given {"files": [{domain, origin, path, doc}], "strays": [path]}, the release's files first, then the
# repository's. A file named domain.yml is a domain's, and any other holds an entity (entity:) or an addition to one
# (extends:). An entity is {domain, origin, path, layer, tool, over, means, stub, sum, variants, fields, relations}, the
# keys its file set, with the domain, origin, and path of the file that defines it. A finding is one sentence that
# names the entity, or the file.
#
# see: modules/bash/model.sh, modules/model/model.schema.json, docs/model.md

import "model.schema" as $model_schema {search: "../model"};
import "domain.schema" as $domain_schema {search: "../model"};

# ----------------------------------------------------------------------------------------------------------------------
# schema
# ----------------------------------------------------------------------------------------------------------------------

# schema is modules/model/model.schema.json, the schema of an entity file, and domain_schema is domain.schema.json, the
# schema of a domain.yml. The check reads every key, name, and pattern from them, so each rule has one definition, and
# bin/ci holds the release's files to the same schemas with ajv.
def schema: $model_schema[0];
def domain_schema: $domain_schema[0];

# file_keys, field_keys, relation_keys, and domain_keys are the keys a model file, a field, a relation, and a domain.yml
# have, in the schema's order.
def file_keys: [schema.properties | keys_unsorted[]];
def field_keys: [schema["$defs"].field.properties | keys_unsorted[]];
def relation_keys: [schema["$defs"].relation.properties | keys_unsorted[]];
def domain_keys: [domain_schema.properties | keys_unsorted[]];

# name_pattern is the pattern of an entity's or a variant's name, member_pattern that of a field's, a relation's, or a
# variant field's name, and read_by_pattern that of a read-by.
def name_pattern: schema["$defs"].name.pattern;
def member_pattern: schema.properties.fields.propertyNames.pattern;
def read_by_pattern: schema["$defs"].field.properties["read-by"].pattern;

# member_from_pattern is the pattern of a from written Entity.member: an entity's name, a dot, and a member's name.
def member_from_pattern: "^" + (name_pattern | ltrimstr("^") | rtrimstr("$")) + "\\." + (member_pattern | ltrimstr("^"));

# scalar_types are the types that need no entity, layers the layers, and statuses and sources the values of a field's
# status and source.
def scalar_types: schema["$defs"].field.properties.type.anyOf[0].enum;
def layers: schema.properties.layer.enum;
def statuses: schema["$defs"].field.properties.status.enum;
def sources: schema["$defs"].field.properties.source.enum;

# listing is an array of words as a phrase: a, b, and c.
def listing:
  if length <= 2 then join(" and ") else (.[:-1] | join(", ")) + ", and " + .[-1] end;

# ----------------------------------------------------------------------------------------------------------------------
# merge
# ----------------------------------------------------------------------------------------------------------------------

# entity_keys are the keys of an entity file that go into the entity.
def entity_keys: ["layer", "tool", "over", "means", "stub", "sum", "variants", "fields", "relations"];

# owned_keys are the keys only the file that defines an entity sets: an extension sets none of them.
def owned_keys: ["layer", "tool", "over", "stub", "sum", "means", "variants"];

# arity_holds is the table of arities: each holds itself and the narrower ones. many holds some, option, and one; some and
# option hold one. Its keys are the arities there are, the schema's.
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

# member_findings($group; $name; $path) are the findings of the fields or relations ($group) a file gives the entity
# $name, the input, a mapping of member name to member: a name the schema's member pattern refuses, and a key the
# schema gives no field or relation.
def member_findings($group; $name; $path):
  ({fields: "field", relations: "relation"})[$group] as $kind
  | ({fields: field_keys, relations: relation_keys})[$group] as $known
  | to_entries[]
  | (if (.key | test(member_pattern)) then empty
      else "\($path) gives \($name) the \($kind) \(.key), whose name does not match \(member_pattern)" end),
    (.key as $m | .value | select(type == "object") | keys_unsorted[] | select(IN($known[]) | not)
      | "\($path) sets \(.) on the \($kind) \($name).\($m), which is not a key of a \($kind); a \($kind) has"
        + " \($known | listing)");

# define($files) is {entities, paths, findings}: each entity file's entity, the first definition of a name standing,
# and a later one a finding. paths holds the path of the file that defines each entity.
def define($files):
  reduce $files[] as $f ({entities: {}, paths: {}, findings: []};
    $f.doc.entity as $name
    | if .entities[$name] != null then
        .findings += ["\($name) is defined twice (\(.paths[$name]), \($f.path))"]
      else
        (reduce ("fields", "relations") as $group ({entity: ({domain: $f.domain, origin: $f.origin, path: $f.path}
            + ($f.doc | with_entries(select(.key | IN(entity_keys[]) and (IN("fields", "relations") | not))))),
            findings: []};
          sound($f.doc; $group; $name; $f.path) as $s
          | .findings += $s.findings
          | if $s.members != null then
              .entity[$group] = $s.members
              | .findings += [$s.members | member_findings($group; $name; $f.path)]
            else . end)) as $built
        | .entities[$name] = $built.entity
        | .findings += (if ($name | test(name_pattern)) then []
            else ["\($f.path) names the entity \($name), which does not match \(name_pattern)"] end)
        | .findings += $built.findings
        | .paths[$name] = $f.path
      end);

# extend($f) is the model {entities, extensions, findings} with the extends file $f applied: the fields and relations it
# adds, the arities and enums it narrows, and a finding for all else. extensions records the file that adds each member.
def extend($f):
  $f.doc.extends as $name
  | if .entities[$name] == null then .findings += ["\($f.path) extends \($name), which no file defines"]
    else
      reduce (owned_keys[] | select(. as $k | $f.doc | has($k))) as $k (.;
        .findings += ["\($f.path) sets \($k) on \($name), which it extends and does not define; \($k) is the defining"
          + " file's to set"])
      | reduce ("fields", "relations") as $group (.;
          sound($f.doc; $group; $name; $f.path) as $s
          | .findings += $s.findings
          | reduce (($s.members // {}) | keys_unsorted[]) as $m (.;
              "\($name).\($m)" as $label
              | if .entities[$name][$group][$m] == null then
                  .entities[$name][$group][$m] = $s.members[$m]
                  | .extensions[$name][$group][$m] = $f.path
                  | .findings += [{($m): $s.members[$m]} | member_findings($group; $name; $f.path)]
                else
                  (.entities[$name][$group][$m] | refine($group; $label; $f.path; $s.members[$m])) as $r
                  | .entities[$name][$group][$m] = $r.value
                  | .findings += $r.findings
                end))
    end;

# hint_findings($path) are the findings of a domain.yml's layout, the input: a layout that is not a mapping, a name the
# schema's name pattern refuses, and a hint that is not {row, col} of whole numbers from 0.
def hint_findings($path):
  if . == null then empty
  elif type != "object" then "\($path) gives layout as something that is not a mapping"
  else
    to_entries[]
    | if (.key | test(name_pattern)) | not then
        "\($path) gives a layout hint to \(.key), which does not match \(name_pattern)"
      elif (.value | type) != "object" or (.value | keys) != ["col", "row"]
        or any(.value[]; type != "number" or . < 0 or . != floor) then
        "\($path) gives \(.key) a layout hint that is not {row, col} of whole numbers from 0"
      else empty end
  end;

# good_hints is a layout, the input, with only the hints that hold.
def good_hints:
  if type != "object" then {}
  else with_entries(select((.key | test(name_pattern)) and (.value | type) == "object" and (.value | keys) == ["col", "row"]
    and all(.value[]; type == "number" and . >= 0 and . == floor))) end;

# domains($files) is {domains, findings}: each domain.yml's domain. The first file for a domain, the release's, defines
# it; a later one, the repository's, may only add layout hints for entities the first gives none. A key the schema gives
# no domain.yml, a domain with no name or intro, a hint that does not hold, and a later file's name, intro, or hint the
# first already gives, are findings.
def domains($files):
  reduce $files[] as $f ({domains: {}, paths: {}, findings: []};
    $f.domain as $d
    | $f.doc as $doc
    | if ($doc | type) != "object" then .findings += ["\($f.path) is not a mapping of keys"]
      else
        .findings += [$doc | keys_unsorted[] | select(IN(domain_keys[]) | not)
          | "\($f.path) sets \(.), which is not a key of a domain.yml; a domain.yml has \(domain_keys | listing)"]
        | .findings += [$doc.layout | hint_findings($f.path)]
        | if .domains[$d] == null then
            .domains[$d] = ($doc | with_entries(select(.key | IN("name", "intro"))))
              + (if $doc | has("layout") then {layout: ($doc.layout | good_hints)} else {} end)
            | .paths[$d] = $f.path
            | .findings += [("name", "intro") as $k | select(($doc[$k] | type) != "string" or $doc[$k] == "")
                | "\($f.path) has no \($k); the domain.yml that defines a domain gives its name and intro"]
          else
            .paths[$d] as $first
            | .findings += [("name", "intro") as $k | select($doc | has($k))
                | "\($f.path) sets \($k) on the domain \($d), which \($first) sets; a later domain.yml adds only layout"
                  + " hints"]
            | reduce ($doc.layout | good_hints | to_entries[]) as $h (.;
                if .domains[$d].layout[$h.key] != null then
                  .findings += ["\($f.path) gives a layout hint to \($h.key), which \($first) gives"]
                else .domains[$d].layout[$h.key] = $h.value end)
          end
      end);

# build gives the model of a document: {domains, entities, extensions, findings}. Every file that defines an entity is
# applied before any that extends one, so an extension may extend an entity a file of the repository defines.
def build:
  [.files[] | select(.path | split("/") | last == "domain.yml")] as $domain_files
  | [.files[] | select((.path | split("/") | last) != "domain.yml")] as $files
  | [$files[] | select((.doc | type) == "object" and (.doc.entity | type) == "string" and .doc.extends == null)] as $entity_files
  | [$files[] | select((.doc | type) == "object" and .doc.entity == null and (.doc.extends | type) == "string")] as $extend_files
  | ([(.strays // [])[]
      | "\(.) is not read: a model file is <domain>/<entity>.yml or <domain>/domain.yml, one directory down"]
    + [$files[] | select((.doc | type) == "object") | .path as $p | .doc | keys_unsorted[]
      | select(IN(file_keys[]) | not)
      | "\($p) sets \(.), which is not a key of a model file; a model file has \(file_keys | listing)"]
    + [$files[] | select(((.doc | type) == "object" and (.doc.entity != null or .doc.extends != null)) | not)
      | "\(.path) names neither an entity nor an extension"]
    + [$files[] | select((.doc | type) == "object" and .doc.entity != null and .doc.extends != null)
      | "\(.path) names both an entity and an extension"]
    + [$files[] | select((.doc | type) == "object" and .doc.extends == null and .doc.entity != null
        and (.doc.entity | type) != "string")
      | "\(.path) gives entity as something that is not a string"]
    + [$files[] | select((.doc | type) == "object" and .doc.entity == null and .doc.extends != null
        and (.doc.extends | type) != "string")
      | "\(.path) gives extends as something that is not a string"]) as $unnamed
  | domains($domain_files) as $domains
  | define($entity_files) as $defined
  | reduce $extend_files[] as $f ({entities: $defined.entities, extensions: {}, findings: $defined.findings}; extend($f))
  | .findings = $unnamed + $domains.findings + .findings
  | {domains: $domains.domains, entities, extensions, findings};

# ----------------------------------------------------------------------------------------------------------------------
# check
# ----------------------------------------------------------------------------------------------------------------------

# show is a value as a finding writes it: a string as it is, anything else as JSON.
def show: if type == "string" then . else tojson end;

# sentence is true for a string with something in it.
def sentence: type == "string" and . != "";

# entity_named($model) is true when the string is the name of an entity of the model.
def entity_named($model): . as $name | type == "string" and ($model.entities | has($name));

# member_path($model; $entity; $group; $m) is the path of the file that gives an entity's field or relation: the
# extension that adds it, or the file that defines the entity.
def member_path($model; $entity; $group; $m): $model.extensions[$entity][$group][$m] // $model.entities[$entity].path;

# type_known($model) is true for a scalar, an {enum: [..]} of distinct words, and the name of an entity.
def type_known($model):
  if type == "string" then IN(scalar_types[]) or entity_named($model)
  elif type == "object" then
    keys == ["enum"] and (.enum | type) == "array" and (.enum | length) > 0 and all(.enum[]; sentence)
    and (.enum | unique | length) == (.enum | length)
  else false end;

# arity_findings($label) is a finding when a field or relation sets an arity that is not in the arity table.
def arity_findings($label):
  if has("arity") then
    .arity as $a
    | if ($a | type) == "string" and (arity_holds | has($a)) then empty
      else "\($label) has arity \($a | show), which is not one, option, many, or some" end
  else empty end;

# ordered_findings($label) is a finding when a field or relation sets ordered to something that is not true or false,
# or on an arity that is not many or some: only a list has an order.
def ordered_findings($label):
  if has("ordered") then
    if (.ordered | type) != "boolean" then "\($label) has ordered \(.ordered | show), which is not true or false"
    elif (has("arity") | not) or (.arity | IN("one", "option")) then
      "\($label) sets ordered on arity \(.arity // "one"), which is not many or some"
    else empty end
  else empty end;

# sentence_findings($label; $keys) are the findings of the keys of the input that, when set, hold a sentence.
def sentence_findings($label; $keys):
  . as $member
  | $keys[] | select(. as $k | $member | has($k) and ((.[$k] | sentence) | not))
  | "\($label) gives \(.) as something that is not a sentence";

# from_findings($model; $label) is a finding when a from written Entity.member names no field or relation. A from that
# is a sentence is not checked.
def from_findings($model; $label):
  if (.from | type) == "string" and (.from | test(member_from_pattern)) then
    (.from | split(".")) as [$e, $m]
    | if ($model.entities[$e].fields[$m] // $model.entities[$e].relations[$m]) != null then empty
      else "\($label) names from \(.from), which is not a field or a relation of an entity" end
  else empty end;

# field_findings($model; $label) are the findings of one field: its type, arity, order, source, status, what a held or a
# derived field must say, its read-by, and its from.
def field_findings($model; $label):
  (if (.type | type_known($model)) then empty
    else "\($label) has type \(.type | show), which is not a scalar, an enum, or an entity" end),
  arity_findings($label),
  ordered_findings($label),
  (if has("source") and (.source | IN(sources[]) | not)
    then "\($label) has source \(.source | show), which is not \(sources | map(tostring) | join(" or "))" else empty end),
  (if has("status") | not then "\($label) has no status; it is \(statuses | listing | sub(" and "; " or "))"
    elif (.status | IN(statuses[]) | not)
    then "\($label) has status \(.status | show), which is not \(statuses | listing | sub(" and "; " or "))"
    else empty end),
  (if .status == "held" and ((."read-by" | sentence) | not) then "\($label) is held and has no read-by" else empty end),
  (if (."read-by" | sentence) and ((."read-by" | test(read_by_pattern)) | not) then
      "\($label) has read-by \(."read-by"), which is not \"<verb> <key>\" as the read-by pattern of"
      + " modules/model/model.schema.json writes it"
    else empty end),
  (if .source == "derived" and ((.from | sentence) | not) then "\($label) is derived and has no from" else empty end),
  sentence_findings($label; ["from", "means"]),
  from_findings($model; $label);

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
  ordered_findings($label),
  (if .inverse != null and .derived != null then "\($label) has both an inverse and a derived; it has one"
    elif .inverse == null and .derived == null then "\($label) has neither an inverse nor a derived; it has one"
    elif .derived != null then
      if (.derived | sentence) then empty else "\($label) gives derived as something that is not a sentence" end
    else inverse_findings($model; $entity; $label) end),
  sentence_findings($label; ["means"]),
  reach_findings($model; $entity; $label);

# kind_findings($model; $name) are the findings of the keys that say what an entity is: its layer, which only a stub may
# leave out; tool, which a native entity names and a logical one does not; over, a list of entities, each once, that
# only a logical entity stands over; sum and stub, which are true or false; and means, a sentence.
def kind_findings($model; $name):
  (if has("layer") | not then (if .stub == true then empty else "\($name) has no layer" end) else empty end),
  (if has("layer") and (.layer | IN(layers[]) | not)
      then "\($name) has layer \(.layer | show), which is not native or logical" else empty end),
  (if .layer == "native" and ((.tool | sentence) | not) then "\($name) is native and names no tool"
    elif .layer == "logical" and .tool != null
      then "\($name) is logical and names a tool, \(.tool | show); only a native entity has one" else empty end),
  (if has("over") | not then empty
    elif (.over | type) != "array" or any(.over[]; type != "string") or (.over | unique | length) != (.over | length)
      then "\($name) gives over as something that is not a list of entity names, each once"
    else
      (if .layer == "native" then
          "\($name) is native and stands over \(.over | join(", ")); only a logical entity stands over others"
        else empty end),
      (.over[] | select(entity_named($model) | not) | "\($name) stands over \(.), which is not an entity")
    end),
  (("sum", "stub") as $k
    | if has($k) and (.[$k] | type) != "boolean"
      then "\($name) has \($k) \(.[$k] | show), which is not true or false" else empty end),
  sentence_findings($name; ["means"]);

# variant_findings($model; $name) are the findings of an entity's variants: a sum has a non-empty mapping of them, each
# named as an entity is, and each a mapping of field to the entity it holds, the field named as a member is; an entity
# that is not a sum has none.
def variant_findings($model; $name):
  if .sum != true then
    if has("variants") then "\($name) has variants and is not a sum" else empty end
  elif (has("variants") | not) or .variants == {} or .variants == [] or .variants == null
    then "\($name) is a sum and has no variants"
  elif (.variants | type) != "object" then "\($name) gives variants as something that is not a mapping"
  else
    .variants | to_entries | sort_by(.key)[]
    | .key as $variant
    | (if ($variant | test(name_pattern)) then empty
        else "\($name) variant \($variant) has a name that does not match \(name_pattern)" end),
      (if (.value | type) != "object" then "\($name) variant \($variant) is not a mapping of field to entity"
        else .value | to_entries | sort_by(.key)[]
          | (if (.key | test(member_pattern)) then empty
              else "\($name) variant \($variant) field \(.key) has a name that does not match \(member_pattern)" end),
            (if (.value | entity_named($model)) then empty
              else "\($name) variant \($variant) field \(.key) names \(.value | show), which is not an entity" end)
        end)
  end;

# layer_findings($model; $name) are the findings of a native entity that reaches into the logical layer: a field whose
# type, a relation whose to, or a variant whose field, names a logical entity. A logical entity is defined over native
# ones, so a native one relates only to native entities and stubs; a logical entity may relate to anything.
def layer_findings($model; $name):
  def logical: entity_named($model) and $model.entities[.].layer == "logical" and $model.entities[.].stub != true;
  def why: "which is logical; a native entity relates only to native entities and stubs";
  if .layer != "native" then empty
  else
    ((.fields // {}) | to_entries | sort_by(.key)[] | select(.value.type | logical)
      | "\($name) is native, and its field \(.key) has type \(.value.type), \(why)"),
    ((.relations // {}) | to_entries | sort_by(.key)[] | select(.value.to | logical)
      | "\($name) is native, and its relation \(.key) goes to \(.value.to), \(why)"),
    (if (.variants | type) == "object" then
        .variants | to_entries | sort_by(.key)[] | .key as $v | .value | select(type == "object") | .[]
        | select(logical) | "\($name) is native, and its variant \($v) holds \(.), \(why)"
      else empty end)
  end;

# entity_findings($model; $name) are the findings of one entity: a stub with fields, each with the file that gives it, a
# name that is both a field and a relation, its kind, its variants, its fields and its relations, each by name, and a
# native entity's reach into the logical layer.
def entity_findings($model; $name):
  $model.entities[$name] as $entity
  | (if $entity.stub == true and (($entity.fields // {}) | length) > 0 then
        "\($name) is a stub and has fields: "
        + ([$entity.fields | keys[] | "\(.) (\(member_path($model; $name; "fields"; .)))"] | join(", "))
      else empty end),
    (($entity.fields // {}) | keys[] as $m | select(($entity.relations // {}) | has($m))
      | "\($name).\($m) is both a field (\(member_path($model; $name; "fields"; $m))) and a relation"
        + " (\(member_path($model; $name; "relations"; $m))); a member is one or the other"),
    ($entity | kind_findings($model; $name)),
    ($entity | variant_findings($model; $name)),
    (($entity.fields // {}) | . as $fields | keys[] as $f | $fields[$f] | field_findings($model; "\($name).\($f)")),
    (($entity.relations // {}) | . as $relations | keys[] as $r | $relations[$r] | relation_findings($model; $name; $r)),
    ($entity | layer_findings($model; $name));

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

# code_spans($runs) are the [start, end] of the code spans of a text, given its runs of backticks as [{o, n}]: a run opens a
# span that the next run of the same length closes, as CommonMark has it, and a run nothing closes is text.
def code_spans($runs):
  def from($i):
    if $i >= ($runs | length) then []
    else
      $runs[$i] as $r
      | ([range($i + 1; $runs | length)] | map(select($runs[.].n == $r.n)) | .[0]) as $j
      | if $j == null then from($i + 1) else [[$r.o, $runs[$j].o + $runs[$j].n]] + from($j + 1) end
    end;
  from(0);

# pieces is a text cut into [{code, text}]: the code spans, as written, and what lies between them.
def pieces:
  . as $t
  | [match("`+"; "g") | {o: .offset, n: .length}] as $runs
  | (reduce code_spans($runs)[] as $s ({pos: 0, out: []};
      .out += [{code: false, text: $t[.pos:$s[0]]}, {code: true, text: $t[$s[0]:$s[1]]}] | .pos = $s[1])) as $cut
  | $cut.out + [{code: false, text: $t[$cut.pos:]}];

# plain escapes the text of a piece that is no code span: a backslash first, so each escape after it is the only one, then a
# <, a *, an _, and a backtick no span closes.
def plain: gsub("\\\\"; "\\\\") | gsub("(?<c>[<*_`])"; "\\" + .c);

# prose is text as markdown reads it as text: outside code spans, a \, a <, a *, and an _ are written \\, \<, \*, and \_,
# so a name in angle brackets is not taken for HTML, nor a lone star or underscore for emphasis or a rule, nor a backslash
# for an escape.
def prose:
  (. // "") | [pieces[] | if .code then .text else .text | plain end] | join("");

# cell is a value as the text of a table cell: nothing is empty, a run of spaces, tabs, and newlines is a space, and a | is
# written \|.
def cell:
  (. // "") | (if type == "string" then . else tojson end) | sub("\n+$"; "") | gsub("[ \t\n]+"; " ") | sub("^ "; "") | sub(" $"; "") | gsub("\\|"; "\\|");

# row is the cells of an array as one line of a table.
def row: "| " + (map(cell) | join(" | ")) + " |";

# table is a header and its rows, as the lines of a table.
def table($header; $rows): [($header | row), ($header | map("---") | row)] + $rows;

# type_text is a type as it is written in a table: a name as it is, an enum as enum(a, b, c).
def type_text:
  if type == "object" and (.enum | type) == "array" then "enum(\(.enum | map(show) | join(", ")))" else show end;

# field_row is the row of a field: its type, its arity with ordered after it when its order is data, its source, its
# status, what reads it, and what it means.
def field_row($name):
  [$name, (.type | type_text), ((.arity | arity_text) + (if .ordered == true then " ordered" else "" end)), (.source // "stored"), .status, (if (.["read-by"] // "") == "" then "" else "`\(.["read-by"])`" end),
    (if .source == "derived" then "derived from \(.from // ""). \(.means // "")" | sub(" $"; "") else .means end | prose)];

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
    ((if .derived != null then "derived: \(.derived)" + (if (.means // "") == "" then "" else ". \(.means)" end) else .means end) | prose)];

# relations gives the table of the relations of a built model's domain, given its name: those of every entity in it, by
# entity then relation. A table is lines joined with newlines.
def relations($domain):
  table(["Relation", "To", "Arity", "Ordered", "Inverse", "Means"];
    [.entities | to_entries | sort_by(.key)[] | select(.value.domain == $domain) | .key as $e
      | (.value.relations // {}) | to_entries | sort_by(.key)[] | .key as $r | .value | relation_row("\($e).\($r)") | row])
  | join("\n");

# ----------------------------------------------------------------------------------------------------------------------
# page
# ----------------------------------------------------------------------------------------------------------------------

# layer_line is the line that says what kind of entity one is: its layer and tool, what a logical one stands over, or, for a
# stub, that it is one.
def layer_line:
  if .stub == true then "Stub: named so other entities can refer to it; its fields are not modelled."
  elif .layer == "native" then "Layer: native (\(.tool))"
  else "Layer: logical" + (if ((.over // []) | length) > 0 then " over \(.over | join(", "))" else "" end)
  end;

# words is a sentence as the words of a paragraph: prose, a run of spaces, tabs, and newlines being one space, and a code span,
# whatever it holds, one word with what touches it.
def words:
  gsub("[ \t\n]+"; " ")
  | reduce pieces[] as $p ({words: [], cur: ""};
      if $p.code then .cur += $p.text
      else
        reduce ($p.text | plain | split(" ") | to_entries[]) as $e (.;
          (if $e.key > 0 and .cur != "" then .words += [.cur] | .cur = "" else . end) | .cur += $e.value)
      end)
  | .words + (if .cur == "" then [] else [.cur] end);

# block_start is true for a word that, at the start of a line, could begin a markdown block: a bullet, a quote, a heading, a
# rule, a fence, a table bar or a delimiter row, a link reference definition, or an ordered number.
def block_start: test("^([-+>#=~|:\\[_]|[0-9]+[.)])");

# unblock escapes the first word of a paragraph so it cannot begin a block.
def unblock:
  if test("^[0-9]+[.)]") then sub("^(?<d>[0-9]+)(?<p>[.)])"; "\(.d)\\\(.p)")
  elif test("^[-+>#=~|:\\[_]") then "\\" + .
  else . end;

# paragraph($width) is a sentence as a paragraph: prose in lines of at most $width characters, or longer for a word that is.
# A line never starts with a word that could begin a block: that word stays on the line before, and the word before it
# goes down with it when the line is too long; the first word of the paragraph is escaped. A code span is never cut.
def paragraph($width):
  words
  | if length == 0 then [] else .[0] |= unblock end
  | reduce .[] as $w ([[]];
      (.[-1]) as $line
      | if ($line | length) == 0 then .[-1] += [$w]
        elif ($line | join(" ") | length) + 1 + ($w | length) <= $width then .[-1] += [$w]
        elif ($w | block_start | not) then . + [[$w]]
        else
          ([range(1; $line | length)] | map(select($line[.] | block_start | not)) | last) as $k
          | if $k == null then .[-1] += [$w]
            else .[-1] = $line[:$k] | . + [$line[$k:] + [$w]] end
        end)
  | map(join(" ")) | join("\n");

# entity_section($name) is the section of one entity of a built model: its name, what it means, its layer line, and its
# fields, as the blocks of a page.
def entity_section($name):
  . as $model
  | .entities[$name] as $entity
  | ["### \($name)"]
    + (if ($entity.means // "" | test("^[ \t\n]*$")) then [] else [$entity.means | paragraph(118)] end)
    + [($entity | layer_line)]
    + (if $entity.stub == true then [] else [$model | fields($name)] end);

# page gives the body of the page of a built model's domain, given its name, as markdown: the domain's intro, its diagram
# as <domain>.svg, its relations, and a section for each of its entities, by name. The page's own file holds the title.
# Blocks are joined by a blank line, with no blank line at the end.
def page($domain):
  . as $model
  | ($model.domains[$domain] // {}) as $d
  | ([$model.entities | to_entries[] | select(.value.domain == $domain) | .key] | sort) as $names
  | ((if ($d.intro // "" | test("^[ \t\n]*$")) then [] else [$d.intro | paragraph(118)] end)
    + ["![\($d.name // $domain): the entities of the domain and how they relate](\($domain).svg)",
       "## Relations", relations($domain), "## Entities"]
    + [$names[] | . as $n | $model | entity_section($n)[]])
  | join("\n\n");
