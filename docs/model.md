# The model

The model describes kit's entities: what each is, what it holds, and how it relates to the others. It is data, one YAML
file for each entity, and the checks, tables, pages, and diagrams of the model are generated from it.

## The files

The release's model is `modules/model/<domain>/<entity>.yml`: one file for each entity, and a `domain.yml` in each
domain's directory. A repository adds its own under `.kit/model/<domain>/`. The domain of a file is the name of its
directory.

A model file uses only the part of YAML that CUE also reads: one document, no anchors, no aliases, and no merge keys.
`model:load`, in `modules/bash/model.sh`, refuses a file that breaks that, and names it.

`modules/model/model.schema.json` is the schema of an entity file, and `modules/model/domain.schema.json` of a
`domain.yml`. `model::check` reads every key, name, and pattern it checks from the two schemas, so each rule has one
definition. `bin/ci` also checks the release's files against the schemas with ajv, and `tests/model.bats` holds ajv and
`kit model check` to the same verdict over a case for each rule.

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
| `fields` | Each field: `type`, `arity`, `ordered`, `source`, `status`, `from`, `read-by`, `means`. |
| `relations` | Each relation: `to`, `arity`, `ordered`, `inverse`, `derived`, `means`. |

The values follow these rules:

- An entity's name and a variant's name are a capital letter, then letters and digits, as `GitCommit`. A field's, a
  relation's, and a variant field's name is lowercase words joined by `-`, as `head-id`.
- An `arity` is `one`, `option`, `many`, or `some`, and is `one` where it is not written. A `many` or a `some` is
  `ordered: true` when its order is data, as a commit's parents are.
- A `type` is a scalar, `Text`, `Int`, `Bool`, `Bytes`, `Path`, `Url`, `Time`, or `Hash`, or `{enum: [..]}` of distinct
  words, or the name of an entity.
- A field's `source` is `stored` or `derived`, and a derived field says where it comes from in `from`. A `from` written
  `Entity.member`, as `GitDir.bare`, names a field or a relation of that entity. A `from` that is a sentence is not
  checked.
- A field's `status` is `held`, `planned`, or `unused`, and every field has one. A held field says which verb prints it
  in `read-by`. A relation has no status, because it holds no value of its own.
- A `read-by` is written `"<verb> <jsonkey>"`. The verb is every word but the last, as `workspace commits`, and the key
  is the last word, dotted where it is nested, as `links.commit`.
- A word of the verb after the first may be an option, written without its value, as in `workspaces --show kind`, which
  reads `kind` from `kit workspaces --show=<workspace> --json`. An option is never the last word.
- A segment `*` of the key stands for any key of a mapping or any element of an array, as in `facts tree.*.blob`, so a
  check of the verb's output walks every key or element there. The last segment is a key, never `*`: a field whose
  values are the elements of a list names the list's key, as `workspace repos checkouts`.
- A relation's `inverse` is `Entity.relation`. `derived`, a sentence, replaces it for a relation with no inverse to
  name.
- A native entity names its `tool` and stands over nothing. A logical entity names no tool, and its `over` is a list of
  entities, each once. Every entity but a stub has a `layer`.

A `domain.yml` has `name`, `intro`, and `layout: {Entity: {row, col}}`, where each entity sits in its domain's diagram,
`row` and `col` being whole numbers from 0. The first `domain.yml` of a domain, the release's, defines it, with its
name and intro. A repository's `domain.yml` for that domain adds layout hints, for the entities it adds or any the
release gives no hint, and sets nothing else.

A stub, `stub: true`, names an entity whose fields the model does not unpack yet. It holds no fields, only the inverse
sides of the relations into it. A stub is a counted gap: `kit model check` counts the stubs, and a page and a diagram
show each as one, so what the model leaves out is visible.

## Reading the files

`model:load [<release-dir> [<repo-dir>]]` prints the model's files as one JSON document:

```json
{"files": [{"domain": "code", "origin": "release", "path": "modules/model/code/commit.yml", "doc": {}}], "strays": []}
```

The release's files come first, then the repository's, each group in path order. The release directory is
`modules/model` of the kit, and the repository's is `.kit/model` of the repository, unless named. Outside a repository
only the release's files are read. A directory that does not exist holds no files.

`strays` names every other file under either directory, which the model does not read: a `.yaml`, a file directly
under the model directory, and a file nested deeper than `<domain>/`. A file or a directory whose name starts with a dot,
which an editor or a file manager makes, is not listed, and nor are the release's two schemas.

`model:load` checks a file's form before it reads the file into JSON, so a file of aliases is refused before anything
expands them. A file it cannot read, or refuses, ends it with status 1 and one line that names the file.

## Extending the model

A repository adds to the release's model with a file that says `extends: <Entity>` where an entity file says
`entity: <Entity>`. `kit/modules/jq/model.jq`'s `model::build` merges the files into one model: every `entity:` file is
applied first, release files before the repository's, then every `extends:` file in the same order. So an extension may
extend an entity another file of the repository defines.

An extension may:

- add a field or a relation whose name the entity does not have, with any of the keys a field or relation has;
- narrow the `arity` of a field or relation the entity has;
- narrow a field's enum type to a subset of its values.

`many` holds `some`, `option`, and `one`; `some` holds `one`; and `option` holds `one`. An arity narrows to one it
holds, itself included, and an arity not written is `one`. `some` and `option` are unrelated, and neither narrows to the
other. A scalar type has no order, so changing a type is not narrowing unless both are `{enum: [..]}` and the new
values are among the old. A relation's `to` does not change.

Two extensions of one member narrow in turn, each from what the one before left. So `many` narrowed to `some`, then to
`option`, is a finding at the second, though `many` holds `option`. This is stricter than CUE's unification, which
would take both and give `one`.

An extension sets nothing else on a field or relation the entity has, and sets none of `layer`, `tool`, `over`, `stub`,
`sum`, `means`, or `variants` on an entity: those are the defining file's. Nothing in an extension removes anything.

`model::build` gives `{domains, entities, extensions, findings}`:

- `domains` holds each domain's `name`, `intro`, and `layout`, by the name of its directory, with the layout hints a
  repository's `domain.yml` adds. A hint that is not `{row, col}` of whole numbers from 0 is left out.
- `entities` holds each entity by name: the keys its file set, with the `domain`, `origin`, and `path` of the file that
  defines it, and what each extension added and narrowed.
- `extensions` names, for each field or relation an extension added, the extension's file, as
  `{Entity: {fields: {name: path}}}`.
- `findings` holds the merge's findings, each a sentence that names the file.

A finding leaves the entity as it was before the file's change that caused it, and the rest of the file still applies.

## What the check holds

`model::check`, in the same module, takes what `model::build` gives and returns the findings as an array of sentences:
the merge's first, then the structural ones, by entity name. In each entity come what it is (stub, layer, sum), then its
fields, then its relations, each by name. An empty array means the model holds. `model::stubs` gives the names of the
stub entities, sorted.

The merge's findings name the file:

- A file the model does not read: `<path> is not read: a model file is <domain>/<entity>.yml or <domain>/domain.yml,
  one directory down`.
- A key a model file does not have: `<path> sets <key>, which is not a key of a model file`, followed by the keys it
  does have. The same holds a field's and a relation's keys, and a `domain.yml`'s.
- A name the schema's pattern refuses: an entity's, a field's, a relation's, or a layout hint's.
- A file other than `domain.yml` that names neither an entity nor an extension, or names both, which defines and
  extends nothing.
- An `entity:` or `extends:` that is not a string, which defines and extends nothing.
- An entity defined by two files: `Commit is defined twice (<path>, <path>)`. The first stands.
- An `extends:` of a name no file defines.
- An arity that widens, a type that changes, a `to` that changes, any other key set on a member the entity has, and a
  key an extension may not set on the entity.
- A `domain.yml` that defines a domain and gives no `name` or `intro`. A later `domain.yml` that sets the `name` or the
  `intro`, or gives a hint the first already gives.

Any pair of arities is a valid relationship, so the check does not rule on arities. These are its findings of an
entity, with `<L>` standing for `Entity.member`:

- A stub with fields: `<Entity> is a stub and has fields: <name> (<path>)`, each with the file that gives it.
- A name that is both a field and a relation: `<L> is both a field (<path>) and a relation (<path>)`.
- An entity with no `layer`, unless it is a stub, and a `layer` that is not `native` or `logical`.
- A `native` entity that names no `tool`, or stands over anything. A `logical` entity that names a `tool`.
- An `over` that is not a list of entity names, each once, and an `over` that names no entity.
- A `sum` or a `stub` that is not `true` or `false`.
- A sum with no `variants`, an entity with `variants` that is not a sum, and `variants` that are not a mapping.
- A variant that is not a mapping of field to entity, whose name or field name the schema refuses, or whose field names
  no entity.
- A field `type` that is not a scalar, an enum of distinct non-empty words, or the name of an entity.
- An `arity`, on a field or a relation, that is not `one`, `option`, `many`, or `some`, `null` included.
- `ordered` that is not `true` or `false`, or that is set on a field or a relation whose arity is `one` or `option`.
- A `source` that is not `stored` or `derived`. A field with no `status`, or one that is not `held`, `planned`, or
  `unused`.
- A `held` field with no `read-by`, and a `read-by` the schema's pattern refuses.
- A `derived` field with no `from`, and a `from` written `Entity.member` that names no field or relation.
- A `means`, a `from`, or a `derived` that is set and is not a sentence.
- A relation whose `to` names no entity, and one with both an `inverse` and `derived`, or with neither.
- An `inverse` that is not written `Entity.relation`, that does not exist, or that does not name this relation back.
- A relation whose `to` is not the entity of its inverse: `<L> goes to <x>, but its inverse <y> is on <z>`. The same rule
  holds the inverse's own `to`, from the inverse's side, so a pair is reported once.
- A relation that is its own inverse and goes to another entity. A relation to its own entity, as `Person.friends` with
  itself as its inverse, is symmetric and holds. So does a pair on one entity, as `Organization.parent` and
  `Organization.children`.
- A relation into a sum, as `Worktree.head` to `Head`, whose variant holds an entity with no relation back to the
  source: `<A>.<r> reaches <E> through <S>, and <E> has no relation back to <A>`. The sum's own inverse is an ordinary
  pair, and a relation back from `<E>` may be derived.
- A native entity whose field, relation, or variant names a logical entity: a logical entity stands over native ones,
  so a native entity relates only to native entities and stubs. A logical entity may relate to any entity.

## The verb

`kit model [--release=<dir>] check` reads the release's model and the repository's, builds the merged model, and checks
it with the findings above. It prints each finding on a line of its own, then, last, `model: N entities, M stubs`,
whatever N and M are, zero included. It exits 0 when there is no finding and 1 when there is one. A file `model:load`
refuses ends it with status 1, and it prints what `model:load` printed.

`kit check` runs the same check in a repository that has a `.kit/model/` directory, and names each finding as one of its
own. A repository without one is checked as any other. `bin/ci` runs `kit model check` after `kit syntax --check`, so a
finding fails the gate.

`--release=<dir>` names a model directory to read in place of the release's `modules/model`, and every `kit model`
subcommand takes it. It takes a directory that exists, once: an empty value, a second one, or a path that is not a
directory exits 2. `kit model` with no subcommand or an unknown one exits 2 and says to run `kit help model`.

A failure of `jq` itself ends any subcommand with 1. Its message goes to stderr and nothing goes to stdout, so a diagram
or a table written to a file never holds it, and no status outside 0, 1, and 2 comes out.

## The tables

`model::fields($name)` and `model::relations($domain)`, in the same module, take what `model::build` gives and return
markdown text: the lines of one table joined with newlines, with no newline at the end.

`kit model [--release=<dir>] table --entity=<name>` prints the fields of an entity, one row each, by name, with the
columns `Field | Type | Arity | Source | Status | Read by | Means`:

- `Arity` is `1`, `0..1`, `0..*`, or `1..*` for `one`, `option`, `many`, and `some`, followed by `ordered` for an ordered
  field. A field with no arity is `1`.
- `Type` is a scalar's name, an entity's name, or `enum(a, b, c)`.
- `Read by` is the verb and key of a held field in a code span, as `` `workspace branches remote` ``, so a key's `*`
  stays a star.
- `Source` is `stored` unless the field is `derived`. The `Means` of a derived field is `derived from <from>. <means>`.
- An entity with no fields has the header and the separator only. A sum has the table `Variant | Field | Type`, one row
  for each field of each variant, in place of fields. A stub has the one line `_<Name> is a stub: named, not yet
  unpacked._`.

`kit model [--release=<dir>] table --domain=<name>` prints the relations of every entity of the domain, stubs included,
by entity then relation, with the columns `Relation | To | Arity | Ordered | Inverse | Means`. `Relation` is
`Entity.relation`. `Ordered` is `ordered` or empty. `Inverse` is `Entity.relation`, or `derived` for a derived relation,
whose sentence is in `Means` as `derived: <sentence>`. A domain with no relations has the header and the separator only.

In a cell, a `|` is written `\|` and a newline is a space. Exactly one of `--entity=` and `--domain=` is given, and none,
or both, exits 2. A name the model does not hold exits 2 and names the entities, or domains, it does. A page holds a
table in a `kit:generate` region whose command is `kit model table --entity=<name>`, so `kit generate --check` names the
page when the model has changed.

## The pages

`model::page($domain)`, in the same module, returns the body of a domain's page as markdown, and `kit model
[--release=<dir>] page --domain=<name>` prints it. A domain the model does not hold exits 2, and the message names the
domains the model holds. So does `page` with no `--domain=`, when it is the only word besides `--release=`; any other
usage error is the guard's. The body is, in order:

- the domain's `intro`, as a paragraph;
- the diagram, `![<Name>: the entities of the domain and how they relate](<domain>.svg)`;
- `## Relations`, with the table of `model::relations`;
- `## Entities`, with a `### <Name>` section for each entity of the domain, by name: what it means as a paragraph, one
  line that says `Layer: native (<tool>)`, or `Layer: logical`, followed by `over <entities>` when it stands over any,
  or, for a stub, `Stub: named so other entities can refer to it; its fields are not modelled.`, and then the table of
  `model::fields`, which a stub has none of.

The page's own file holds the title. A paragraph is wrapped at 118 characters, so markdownlint's line length holds. A
paragraph, and the `Means` of a field or a relation, are written so markdown reads them as text:

- Outside code spans, a backslash, a `<`, a `*`, an `_`, and a backtick no span closes are each escaped with a
  backslash, so a placeholder such as `<name>` is not read as HTML, and `a\|b` keeps its backslash. A code span pairs
  with the next run of backticks of the same length, as CommonMark has it, and is left as written.
- A run of spaces, tabs, and newlines is one space, in a paragraph and in a cell, and a `means` or `intro` of nothing
  but those is empty and writes no paragraph.
- A code span is one word, so a wrap never cuts it. A line never starts with a word that opens a block: a word that
  begins with one of `-`, `+`, `>`, `#`, `=`, `~`, `|`, `:`, `[`, `_`, or a number and `.` or `)` could open a bullet, a
  quote, a heading, a thematic break or setext underline, a fence, a table bar or delimiter row, a link reference
  definition, or an ordered list. That word stays on the line before, and the word before it goes down with it when the
  line would be too long. The first word of a paragraph is escaped instead, as `\-` or `1\.`.
- A word longer than the width, a URL for one, stands alone on its line.

A table row is not wrapped, as the markdown style lets a table run long. Write a URL or an address in a `means` between
backticks.

## The generated pages and diagrams

A domain the model holds may have a page and a diagram under `docs/entities/`, written from the model and never edited
by hand:

| File | Written by |
| --- | --- |
| `docs/entities/<domain>.md` | `kit generate docs/entities/<domain>.md`, from the `kit:generate` region whose command is `kit model page --domain=<domain>` |
| `docs/entities/<domain>.svg` | `kit model svg --domain=<domain> > "${TMPDIR:-/tmp}/<domain>.svg" && mv "${TMPDIR:-/tmp}/<domain>.svg" docs/entities/<domain>.svg` |

[docs/entities/README.md](entities/README.md) says which domains have them. The other diagrams in `docs/entities/`, and
the overview, are hand-made, and are replaced as each domain gets its pass.

`bin/ci` holds the files to the model. `kit generate --check`, which `kit check` runs, fails on a page that differs
from what its command prints. `bin/ci` finds each diagram whose domain has a model directory and a page, compares it
with `kit model svg --domain=<domain>`, and fails on a difference, naming the file and the command that writes it. A
warning the verb prints must be on `bin/ci`'s list of expected warnings, each with the reason no layout hint removes
it, and a listed warning that no longer comes fails as stale.

## The diagrams

`modelsvg::domain($name)` and `modelsvg::overview`, in `kit/modules/jq/modelsvg.jq`, take what `model::build` gives and
return SVG text. `kit model [--release=<dir>] svg --domain=<name>` prints the diagram of one domain, and `svg
--overview` the diagram of every domain. Exactly one of `--domain=` and `--overview` is given, and none, or both, exits
2. A domain the model does not hold exits 2 and names the domains it does.

The diagram of a domain draws a card for each of its entities:

- the name, on a band tinted with the domain's color;
- what the entity means, wrapped to the card;
- `native: <tool>` for a native entity, and `logical` for a logical one, then `over: <entities>` when it has any;
- `N held, M planned, K unused`, its fields by status, except for a sum or a stub;
- each variant of a sum, as `Variant(field: Type)`, one a line;
- a footer whose dot is green when a field is held, with the verbs that read the held fields, and hollow when none is.

A stub's card is dashed and grey, and has no footer.

A card goes in the row and column its domain's `layout` gives it. An entity with no hint goes one column right of the
deepest entity that needs it, where an entity needs what a relation of arity `one` or `some` goes to. One that nothing
needs is in the first column. A cycle of needs is broken at the relation back into an entity already on the path, with
the entities taken in name order. In a column, the entities with no hint go below the hinted ones, in name order. A row
or column that holds no card closes up. A card is 236 wide, and a row is as tall as its tallest card. Columns are at
least 64 apart and rows at least 56 apart: a gap or a gutter widens to hold the lines, loops, and stubs it carries, and
the rows and columns after it move along.

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

A line between two cards leaves and reaches the bottom or top of each, and runs only in the gaps between rows and the
gutters between columns, so it never passes through a card. A line between a card and the row under it, or two cards of
one row, runs along one track in the gap between them. Any other line runs along a track in the gap by its first card,
along a track in a gutter between the two cards' columns, and along a track in the gap by its other card. Each line has
a track of its own in each gap and gutter, and each end has a point of its own on its card's edge, so no two lines
share a track or an end.

The lines are planned on the grid of cards before anything has a size, so the plan says how many tracks each gap and
gutter carries. Tracks are 6 apart.

- A gap is 56 high, or higher when its tracks need it. Above the tracks is a band for the labels of the card over the
  gap, and under them a band for the labels of the card under it. A band holds as many rows of labels as the labels by
  one card edge take, the widest first, each in the first row it fits with 10 between, up to three rows: 10 and 12 for
  each row, 22 for one. A fourth row would lie past the 40 units a label keeps to its end.
- A gutter is 64 wide, or wider: the loops and stubs of the column left of it, with their labels, come first, then 8
  of clear room, then its tracks, then 18 before the next column.
- A row is as tall as its tallest card, and as tall as a card with n ends on its right side needs to hold them 20
  apart: 30 + 20(n + 1). The plan is made before any size, and no size changes it.

The lines are drawn first, then the cards, then the labels. Each label has a white halo and sits within 40 units of its
own end. It takes the nearest place there that covers no card and no other label, and stays at least 3 from every
other line. A place that covers another label costs a hundred times one that covers a line, so a label crosses lines
before it lies on a label, which no reader could tell apart. The widest labels are placed first. A label set on its own
line is tried last, and only 12 or more from its end, so it never covers its own arrowhead.

When no place is clear, the search widens in steps of 6, and keeps only the places within 40 units of the end: along a
top or bottom edge, to about 35 either way; on the right side of a card, up and down by up to 36, and outward by a step
or a few, as far as the 40 units allow. When even that finds none, the label takes the cheapest place inside the
diagram. It may cover a line there, but never leaves the canvas, and `kit model svg` names its entity in a warning on
stderr. The SVG is unchanged by the warning, and the exit status stays 0.

The overview draws a panel for each domain, five to a row, by name: the domain's name and intro, and its entities as
pills, a stub's dashed. A domain of the release has a fixed color, and `config` and `configuration` share one. Any other
domain takes one of six more, by its place among the sorted names of the model's domains.

The output is the same bytes for the same model, run again or under any locale. Every object is read in sorted order,
every coordinate is rounded to one decimal, and the text of a name, a sentence, or an intro is escaped, so a `<`, a `&`,
or a quote leaves the SVG well-formed. A character XML does not allow, a control character other than a tab, a newline,
or a return, and U+FFFE and U+FFFF, is dropped.

`tests/fixtures/model/lab/lab.svg` is the diagram of an eleven-entity domain with no layout hints, and `tests/model.bats`
compares the output with it byte for byte, so a change to the layout or the router shows as a diff. After a change you
mean, write it afresh from the repository root. The command writes to a scratch file first, so a failed run leaves the
golden as it was:

```bash
kit/bin/kit model --release=tests/fixtures/model/lab/release svg --domain=lab > "${TMPDIR:-/tmp}/lab.svg" \
  && mv "${TMPDIR:-/tmp}/lab.svg" tests/fixtures/model/lab/lab.svg
```
