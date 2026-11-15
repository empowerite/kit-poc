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

## The verb

`kit model [--release=<dir>] check` reads the release's model and the repository's, builds the merged model, and checks
it with the findings above. It prints each finding on a line of its own, then, last, `model: N entities, M stubs`.
It exits 0 when there is no finding and 1 when there is one. A file `model:load` refuses ends it with status 1, and it
prints what `model:load` printed.

`--release=<dir>` names a model directory to read in place of the release's `modules/model`; every `kit model`
subcommand takes it. The repository's `.kit/model` is read as before. `kit model` with no subcommand or an unknown one
exits 2 and says to run `kit help model`.

`bin/ci` runs `kit model check` after `kit syntax --check`, so a finding fails the gate.

The last line is `model: N entities, M stubs` whatever N and M are, zero included. `--release=` takes a directory that
exists, and once: an empty value, a second one, or a directory that is not there exits 2. A failure of `jq` itself
ends it with 1 and jq's message, so no status outside 0, 1, and 2 comes out.

## The tables

`model::fields($name)` and `model::relations($domain)`, in the same module, take what `model::build` gives and return
markdown text: the lines of one table joined with newlines, with no newline at the end.

`kit model [--release=<dir>] table --entity=<name>` prints the fields of an entity, one row each, by name, with the
columns `Field | Type | Arity | Source | Status | Read by | Means`:

- `Arity` is `1`, `0..1`, `0..*`, or `1..*` for `one`, `option`, `many`, and `some`; a field with no arity is `1`;
- `Type` is a scalar's name, an entity's name, or `enum(a, b, c)`;
- `Source` is `stored` unless the field is `derived`; the `Means` of a derived field is `derived from <from>. <means>`;
- an entity with no fields has the header and the separator only. A sum has the table `Variant | Field | Type`, one row
  for each field of each variant, in place of fields. A stub has the one line `_<Name> is a stub: named, not yet
  unpacked._`.

`kit model [--release=<dir>] table --domain=<name>` prints the relations of every entity of the domain, stubs included,
by entity then relation, with the columns `Relation | To | Arity | Ordered | Inverse | Means`. `Relation` is
`Entity.relation`; `Ordered` is `ordered` or empty; `Inverse` is `Entity.relation`, or `derived` for a derived relation,
whose sentence is in `Means` as `derived: <sentence>`. A domain with no relations has the header and the separator only.

In a cell, a `|` is written `\|` and a newline is a space. Exactly one of `--entity=` and `--domain=` is given; none, or
both, exits 2. A name the model does not hold exits 2 and names the entities, or domains, it does. A page holds a table
in a `kit:generate` region whose command is `kit model table --entity=<name>`, so `kit generate --check` names the page
when the model has changed.

## The diagrams

`modelsvg::domain($name)` and `modelsvg::overview`, in `kit/modules/jq/modelsvg.jq`, take what `model::build` gives and
return SVG text. `kit model [--release=<dir>] svg --domain=<name>` prints the diagram of one domain, and `svg
--overview` the diagram of every domain. Exactly one of `--domain=` and `--overview` is given; none, or both, exits 2.
A domain the model does not hold exits 2 and names the domains it does.

The diagram of a domain draws a card for each of its entities:

- the name, on a band tinted with the domain's color;
- what the entity means, wrapped to the card;
- `native: <tool>` for a native entity, and `logical` for a logical one, then `over: <entities>` when it has any;
- `N held, M planned, K unused`, its fields by status, except for a sum or a stub;
- each variant of a sum, as `Variant(field: Type)`, one a line;
- a footer whose dot is green when a field is held, with the verbs that read the held fields, and hollow when none is.

A stub's card is dashed and grey, and has no footer.

A card goes in the row and column its domain's `layout` gives it. An entity with no hint goes one column right of the
deepest entity that needs it, where an entity needs what a relation of arity `one` or `some` goes to; one that nothing
needs is in the first column. A cycle of needs is broken at the relation back into an entity already on the path, with
the entities taken in name order. In a column, the entities with no hint go below the hinted ones, in name order. A row
or column that holds no card closes up. A card is 236 wide, and a row is as tall as its tallest card. Columns are at least
64 apart and rows at least 56 apart: a gap or a gutter widens to hold the lines, loops, and stubs it carries, and the
rows and columns after it move along.

Each relation of the domain is a line:

- A pair of inverse relations, `A.r` to `B` and `B.s` to `A`, is one line between the two cards, with an arrow at both
  ends. At `B`'s end it reads the name and arity of `A.r`, as `r  1`, and at `A`'s end those of `B.s`. An arity reads
  `1`, `0..1`, `0..*`, or `1..*`, and an ordered relation adds `{ordered}`.
- A derived relation is a dashed arrow to where it goes, with its name, its arity, and `derived` at that end. A relation
  whose inverse does not name it back is a solid arrow, labelled the same way, without `derived`.
- A relation to its own entity, or a pair on one entity, is a loop on the right side of the card, with its labels past
  it. A relation that is its own inverse has one label.
- A relation to an entity of another domain is a short arrow out of the right side of the card, with its name and
  arity past it, then that entity's name in grey. That entity has no card, so a diagram holds only its own domain.

A line between two cards leaves and reaches the bottom or top of each, and runs only in the gaps between rows and
the gutters between columns, so it never passes through a card. A line between a card and the row under it, or two
cards of one row, runs along one track in the gap between them. Any other line runs along a track in the gap by its
first card, along a track in a gutter between the two cards' columns, and along a track in the gap by its other card.
Each line has a track of its own in each gap and gutter, and each end has a point of its own on its card's edge, so no
two lines share a track or an end.

The lines are planned on the grid of cards before anything has a size, so the plan says how many tracks each gap and
gutter carries. Tracks are 6 apart.

- A gap is 56 high, or higher when its tracks need it. Above the tracks is a band for the labels of the card over the
  gap, and under them a band for the labels of the card under it: 22, one row of labels, or 34, two rows, when the
  labels by one card edge, with 10 between, are wider than the card.
- A gutter is 64 wide, or wider: the loops and stubs of the column left of it, with their labels, come first, then 8
  of clear room, then its tracks, then 18 before the next column.
- A row is as tall as its tallest card, and as tall as a card with n ends on its right side needs to hold them 20
  apart: 30 + 20(n + 1). The plan is made before any size, and no size changes it.

The lines are drawn first, then the cards, then the labels. Each label has a white halo and sits within 40 units of its
own end. It takes the nearest place there that covers no card and no other label, and stays at least 3 from every
other line. The widest labels are placed first. A label set on its own line is tried last, and only 12 or more from its
end, so it never covers its own arrowhead. When no place is clear, the search widens, in steps of 6 along the side, up
to 36 on the right side of a card and 48 on its top or bottom. When even that finds none, the label takes the cheapest
place, and `kit model svg` names its entity in a warning on stderr. The SVG is unchanged by it, and the exit status
stays 0.

The overview draws a panel for each domain, five to a row, by name: the domain's name and intro, and its entities as
pills, a stub's dashed. A domain of the release has a fixed color, and `config` and `configuration` share one. Any
other domain takes one of six more, by its place among the sorted names of the model's domains.

The output is the same bytes for the same model, run again or under any locale. Every object is read in sorted order,
every coordinate is rounded to one decimal, and the text of a name, a sentence, or an intro is escaped, so a `<`, a
`&`, or a quote leaves the SVG well-formed.

`tests/fixtures/model/lab/lab.svg` is the diagram of an eleven-entity domain with no layout hints, and
`tests/model.bats` compares the output with it byte for byte, so a change to the layout or the router shows as a diff.
After a change you mean, write it afresh from the repository root. The command writes to a scratch file first, so a
failed run leaves the golden as it was:

```bash
kit/bin/kit model --release=tests/fixtures/model/lab/release svg --domain=lab > "${TMPDIR:-/tmp}/lab.svg" \
  && mv "${TMPDIR:-/tmp}/lab.svg" tests/fixtures/model/lab/lab.svg
```
