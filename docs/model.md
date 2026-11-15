# The model

The model describes kit's entities: what each is, what it holds, and how it relates to the others. It is data, one YAML
file for each entity, and the checks, tables, and diagrams of the model are generated from it.

## The files

The release's model is `modules/model/<domain>/<entity>.yml`: one file for each entity, and a `domain.yml` in each
domain's directory. A repository adds its own under `.kit/model/<domain>/`. The domain of a file is the name of its
directory.

A model file uses only the part of YAML that CUE also reads: one document, no anchors, no aliases, and no merge keys.
`model:load`, in `modules/bash/model.sh`, refuses a file that breaks that, and names it.

`modules/model/model.schema.json` is the schema of an entity file, and `modules/model/domain.schema.json` of a
`domain.yml`. `bin/ci` checks each file against its schema.

An entity file has these keys:

| Key | Holds |
| --- | --- |
| `entity` or `extends` | The entity's name, or the name of the entity this file adds to. |
| `layer` | `native`, an entity of a tool, or `logical`, one kit makes over others. |
| `tool` | The tool a native entity lives in, as `git`. |
| `over` | The entities a logical entity stands over. |
| `means` | What the entity is, in a sentence. |
| `stub` | `true` for an entity named only so that others can refer to it. |
| `sum`, `variants` | `sum: true` makes the entity one of its `variants: {Name: {field: Entity}}`. |
| `fields` | Each field: `type`, `arity`, `source`, `status`, `from`, `read-by`, `means`. |
| `relations` | Each relation: `to`, `arity`, `ordered`, `inverse`, `derived`, `means`. |

An `arity` is `one`, `option`, `many`, or `some`, and is `one` where it is not written. A scalar `type` is `Text`,
`Int`, `Bool`, `Bytes`, `Path`, `Url`, `Time`, or `Hash`, or `{enum: [..]}`, or the name of an entity. A field's `source`
is `stored` or `derived`, and a derived field says where it comes from in `from`. Its `status` is `held`, `planned`, or
`unused`, and a held field says which verb reads it in `read-by`, written `"<verb> <jsonkey>"`. A relation's `inverse`
is `Entity.relation`; `derived`, a sentence, replaces it for a relation with no inverse to name.

A `domain.yml` has `name`, `intro`, and `layout: {Entity: {row, col}}`, where each entity sits in its domain's diagram.

## Reading the files

`model:load [<release-dir> [<repo-dir>]]` prints the model's files as one JSON document:

```json
{"files": [{"domain": "code", "origin": "release", "path": "modules/model/code/commit.yml", "doc": {}}]}
```

The release's files come first, then the repository's, each group in path order. The release directory is
`modules/model` of the kit and the repository's is `.kit/model`, unless named. A directory that does not exist holds
no files. A file `model:load` cannot read, or refuses, ends it with status 1 and one line that names the file.

## Extending the model

A repository adds to the release's model with a file that says `extends: <Entity>` where an entity file says
`entity: <Entity>`. `kit/modules/jq/model.jq`'s `model::build` merges the files into one model: every `entity:` file is
applied first, release files before the repository's, then every `extends:` file in the same order. So an extension may
extend an entity another file of the repository defines.

An extension may:

- add a field or a relation whose name the entity does not have, with any of the keys a field or relation has;
- narrow the `arity` of a field or relation the entity has;
- narrow a field's enum type to a subset of its values.

Narrowing follows `many` holds `some`, `option`, and `one`; `some` holds `one`; `option` holds `one`. An arity is also
its own narrowing, and an arity not written is `one`. `some` and `option` are unrelated, and neither narrows to the
other. A scalar type has no order, so changing a type is not narrowing unless both are `{enum: [..]}` and the new
values are among the old. A relation's `to` does not change.

An extension sets nothing else on a field or relation the entity has, and sets none of `layer`, `tool`, `over`, `stub`,
`sum`, `means`, or `variants` on an entity: those are the defining file's. Nothing in an extension removes anything.

`model::build` gives `{domains, entities, findings}`. Each finding is one sentence that names the entity, the field or
relation, and the file. These are findings:

- an entity defined by two files, as `Commit is defined twice (<path>, <path>)`; the first stands;
- an `extends:` of a name no file defines;
- an arity that widens, a type that changes, or a `to` that changes;
- any other key set on a field or relation the entity has;
- a key an extension may not set on the entity.
- a file other than `domain.yml` that names neither an entity nor an extension, as `<path> names neither an entity nor an
  extension`.
- a file that names both, as `<path> names both an entity and an extension`; it defines and extends nothing.

A finding leaves the entity as it was before the file's change that caused it; the rest of the file still applies.
