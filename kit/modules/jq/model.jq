# model.jq - the model of kit's entities, merged from its files (jq module)
# ----------------------------------------------------------------------------------------------------------------------
# import "model" as model; with jq -L "${kit_jq}". It holds one section for each concern, in the order a run takes them:
#
#   merge   build turns the document model:load prints into one model, {domains, entities, findings}, and holds the
#           repository's additions to the narrowing the release allows.
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

# narrows($old; $new) is true when an arity $new is $old or narrower: many holds some, option, and one; some and option
# hold one. An arity not written is one.
def narrows($old; $new):
  ({many: ["many", "some", "option", "one"], some: ["some", "one"], option: ["option", "one"], one: ["one"]}[$old // "one"]
    // []) as $held
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
        if narrows($old.arity; $new.arity) then .value.arity = $new.arity
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

# define($files) is {entities, paths, findings}: each entity file's entity, the first definition of a name standing,
# and a later one a finding. paths holds the path of the file that defines each entity.
def define($files):
  reduce $files[] as $f ({entities: {}, paths: {}, findings: []};
    $f.doc.entity as $name
    | if .entities[$name] != null then
        .findings += ["\($name) is defined twice (\(.paths[$name]), \($f.path))"]
      else
        .entities[$name] = ({domain: $f.domain, origin: $f.origin}
          + ($f.doc | with_entries(select(.key | IN(entity_keys[])))))
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
          reduce (($f.doc[$group] // {}) | keys_unsorted[]) as $m (.;
            "\($name).\($m)" as $label
            | if .entities[$name][$group][$m] == null then .entities[$name][$group][$m] = $f.doc[$group][$m]
              else
                (.entities[$name][$group][$m] | refine($group; $label; $f.path; $f.doc[$group][$m])) as $r
                | .entities[$name][$group][$m] = $r.value
                | .findings += $r.findings
              end))
    end;

# build gives the model of a document: {domains, entities, findings}. Every file that defines an entity is applied before
# any that extends one, so an extension may extend an entity a file of the repository defines.
def build:
  [.files[] | select(.path | split("/") | last == "domain.yml")] as $domain_files
  | [.files[] | select((.path | split("/") | last) != "domain.yml")] as $files
  | [$files[] | select((.doc | type) == "object" and .doc.entity != null)] as $entity_files
  | [$files[] | select((.doc | type) == "object" and .doc.entity == null and .doc.extends != null)] as $extend_files
  | [$files[] | select(((.doc | type) == "object" and (.doc.entity != null or .doc.extends != null)) | not)
      | "\(.path) names neither an entity nor an extension"] as $unnamed
  | define($entity_files) as $defined
  | reduce $extend_files[] as $f ({entities: $defined.entities, findings: $defined.findings}; extend($f))
  | .findings += $unnamed
  | {domains: ([$domain_files[] | {key: .domain, value: (.doc | with_entries(select(.key | IN("name", "intro", "layout"))))}]
        | from_entries),
      entities, findings};
