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
