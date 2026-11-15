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
- an `entity:` or `extends:` that is not a string, as `<path> gives entity as something that is not a string`; the file
  defines and extends nothing.

A finding leaves the entity as it was before the file's change that caused it; the rest of the file still applies.

## What the check holds

`model::check`, in the same module, takes what `model::build` gives and returns the findings as an array of sentences:
the merge's first, then the structural ones, by entity name. In each entity come what it is (stub, layer, sum), then its
fields, then its relations, each by name. An empty array means the model holds. `model::stubs` gives the names of the
stub entities, sorted.

Any pair of arities is a valid relationship, so the check does not rule on arities. These are its findings, with
`<L>` standing for `Entity.member`:

- a stub with fields: `<Entity> is a stub and has fields: <names>`. A stub may hold relations, the inverse sides of
  relations into it;
- an entity with no `layer`: `<Entity> has no layer`. A stub, `stub: true`, needs none;
- a `layer` that is not `native` or `logical`: `<Entity> has layer <x>, which is not native or logical`;
- a `native` entity that names no `tool`: `<Entity> is native and names no tool`; a `logical` entity that names one.
  `over` is not checked;
- a `sum` or a `stub` that is not `true` or `false`: `<Entity> has sum <x>, which is not true or false`;
- a sum with no `variants`: `<Entity> is a sum and has no variants`; an entity with `variants` that is not a sum:
  `<Entity> has variants and is not a sum`;
- a sum whose `variants` are not a mapping, whose variant is not a mapping of field to entity, or whose variant field
  names no entity;
- a field `type` that is not a scalar (`Text`, `Int`, `Bool`, `Bytes`, `Path`, `Url`, `Time`, `Hash`), an
  `{enum: [..]}` of a non-empty list of strings, or the name of an entity:
  `<L> has type <x>, which is not a scalar, an enum, or an entity`;
- an `arity`, on a field or a relation, that is not `one`, `option`, `many`, or `some`, `null` included: `<L> has arity
  <x>, which is not one, option, many, or some`;
- a `source` that is not `stored` or `derived`, and a `status` that is not `held`, `planned`, or `unused`;
- a `held` field with no `read-by`: `<L> is held and has no read-by`; a `derived` field with no `from`;
- a relation whose `to` names no entity;
- a relation with both an `inverse` and `derived`, or with neither, and a `derived` that is not a sentence;
- an `inverse` that is not written `Entity.relation`, that does not exist, or that does not name this relation back:
  `<L> names inverse <x>, which does not exist` and `<L> names inverse <x>, which does not name <L> back`;
- a relation whose `to` is not the entity of its inverse: `<L> goes to <x>, but its inverse <y> is on <z>`. The same rule
  holds the inverse's own `to`, from the inverse's side, so a pair is reported once;
- a relation that is its own inverse and goes to another entity. A relation to its own entity, as
  `Person.friends` with itself as its inverse, is symmetric and holds; so does a pair on one entity, as
  `Organization.parent` and `Organization.children`;
- `ordered` that is not `true` or `false`, or is set on a relation whose arity is `one` or `option`;
- a relation into a sum, as `Worktree.head` to `Head`, whose variant holds an entity with no relation back to the
  source: `<A>.<r> reaches <E> through <S>, and <E> has no relation back to <A>`. The sum's own inverse is an ordinary
  pair, and a relation back from `<E>` may be derived.
