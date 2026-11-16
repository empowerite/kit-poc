# The entity model Implementation Plan

**Status, 2026-11-15:** Tasks 1 to 6 are built and reviewed (commits ea5811df to f2b39ac6, issue #597); tasks 7 to 11
are not started.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Model files, one per entity, with arity, fields, and layers; a `kit model` verb that checks them and writes
tables and SVGs from them; and the first pass of content, Code and git.

**Architecture:** YAML files under `kit/modules/model/<domain>/<entity>.yml` (the release) and `.kit/model/<domain>/`
(a repository's additions) are read by `modules/bash/model.sh` into one JSON document. `modules/jq/model.jq` merges
extensions, checks the model, and writes the tables; `modules/jq/modelsvg.jq` writes the diagrams. `kit/bin/kit-model`
is the verb. Pages under `docs/entities/` hold generated regions.

**Tech Stack:** bash, jq (1.7 floor, as `tests/jq.bats` holds), yq (mikefarah, through `modules/bash/yaml.sh`), bats,
ajv for the file schema.

**Spec:** `docs/superpowers/specs/2026-11-15-entity-model-design.md`. Issue: #597.

## Global Constraints

- A model file uses only the part of YAML that CUE also reads: one document, no anchors, no aliases, no merge keys.
- The checks and tables are bash, jq, and yq; no Python.
- The diagram output is byte-stable: same model, same bytes, under `LC_ALL=C` and any locale.
- Everything in `kit/` is written for a consumer: no file names a consumer, a person, or another repository. A path in
  a file under `kit/` is written from `kit/`, as `modules/model/code/commit.yml`.
- Every option with a value is `--opt=value`. Exit 0 ok, 1 findings, 2 usage.
- A markdown page that shows generated tables holds them in `kit:generate` regions.
- Each commit subject starts with `#597`; commit with `kit commit --message=…` and stage only the task's own paths, for
  other sessions share this worktree.
- No known wrong case is left: a test for it, or a fix.

## Review Focus

- A relation to itself (`Organization.parent` and `children`, `GitCommit.parents` and `children`): the inverse is the
  same entity; the check must not report it missing or its own inverse.
- An extension that widens (`one` to `many`), or narrows (`many` to `option`), and one that removes: only the first and
  the last are refused.
- A model file with an anchor, an alias, a merge key, or two documents: refused with the file named.
- Two files that define one entity, in the release and in the repository, or an `extends` of an entity nobody defines.
- The same model run twice, and under another locale: the same SVG bytes.

## File Structure

- `kit/modules/model/<domain>/<entity>.yml`, `kit/modules/model/<domain>/domain.yml`: the release's model.
- `kit/modules/model/model.schema.json`: the schema of an entity file; `domain.schema.json`: of `domain.yml`.
- `kit/modules/bash/model.sh`: `model:load`. `kit/modules/jq/model.jq`: merge, check, tables. `kit/modules/jq/modelsvg.jq`.
- `kit/bin/kit-model`: the verb. `docs/model.md`: the file format and the verb. `docs/entities/<domain>.md`: pages.
- `tests/model.bats`, `tests/jq/model.test`, `tests/jq/modelsvg.test`, `tests/model-reality.bats`, `tests/fixtures/model/`.

## The file format (fixed here; later tasks use these keys)

An entity file: `entity:` or `extends:` (a name), `layer: native|logical`, `tool:` (native only, as `git`), `over:` (a
list of entity names, logical only), `means:`, `stub: true`, `sum: true` with `variants: {Name: {field: Entity}}`,
`fields: {name: {type, arity, source, status, from, read-by, means}}`, `relations: {name: {to, arity, ordered,
inverse, derived, means}}`. `arity` is `one|option|many|some`, default `one`. `source` is `stored|derived`; `status` is
`held|planned|unused`. A scalar `type` is one of `Text Int Bool Bytes Path Url Time Hash`, or `{enum: [..]}`, or an
entity name. `read-by` is `"<verb> <jsonkey>"` and is required when `status: held`; `from` is required when `source:
derived`. `inverse` is `Entity.relation`; `derived` is a sentence and replaces `inverse`. `domain.yml`: `name`, `intro`,
`layout: {Entity: {row, col}}`.

---

### Task 1: The model files and their loader

**Files:**

- Create: `kit/modules/model/model.schema.json`, `kit/modules/model/domain.schema.json`, `kit/modules/bash/model.sh`,
  `tests/model.bats`, `tests/fixtures/model/` (one directory per case), `docs/model.md` (section "The files")
- Modify: `bin/ci` (ajv over `kit/modules/model/*/*.yml` against the two schemas)

**Interfaces:**

- Produces: `model:load [--release-only]` prints one JSON document `{"files": [{"domain": str, "origin":
  "release"|"repository", "path": str, "doc": object}]}`, release files first, each group in path order; exits 1 naming
  the file when one is malformed.

- [ ] **Step 1: Write `tests/model.bats` cases:** `model:load reads the release's files in path order` (assert the
  first `path` is `modules/model/code/...` and `origin` is `release`); `a repository's .kit/model files follow the
  release's` (a fixture with `.kit/model/code/extra.yml`); `a file with an anchor is refused with its path`, `…an alias`,
  `…a merge key`, `…two documents` (each exits 1 and the output names the path).
- [ ] **Step 2: Run** `kit/bin/kit tools run bats tests/model.bats`; expect FAIL (`model:load` undefined).
- [ ] **Step 3: Implement `model:load` in `modules/bash/model.sh`** through `yaml:json` (`modules/bash/yaml.sh`); detect
  an anchor or alias with `yq '.. | select(anchor != "" or kind == "alias")'` and a merge key by the `<<` key.
- [ ] **Step 4: Write the two schemas** from "The file format" above, and add the ajv lines to `bin/ci` beside the
  package schema's.
- [ ] **Step 5: Run** the bats file; expect PASS. Run `bin/ci` up to the ajv step with a model file that has a bad
  `arity: lots`; expect ajv to fail it.
- [ ] **Step 6: Commit** `#597 model: the model files, their schemas, and the loader`.

### Task 2: Merge, and the extension rules

**Files:**

- Create: `kit/modules/jq/model.jq` (the merge part), `tests/jq/model.test`
- Modify: `docs/model.md` ("Extending the model")

**Interfaces:**

- Consumes: Task 1's document.
- Produces: `import "model" as model;` `model::build` takes Task 1's document and outputs `{"domains": {name: {name,
  intro, layout}}, "entities": {Name: {domain, origin, layer, tool, over, means, stub, sum, variants, fields,
  relations}}, "findings": [str]}`. A finding is one sentence naming the entity and the file.

- [ ] **Step 1: Write jq tests** in `tests/jq/model.test`, one case each, asserting the `findings`:
  `an extends adds a field`, `an extends adds a relation`, `an extends narrows many to some`, `…option to one`, `…many
  to option` (no finding for these); `an extends widens one to many` (finding), `…changes a field's type`, `…removes
  nothing it cannot` (an `extends` has no removal syntax, so assert a repository file that redefines a core entity with
  `entity:` is a finding: "defined twice"), `an extends of an unknown entity` (finding), `an extends sets layer or
  status` (finding: both are the release's).
- [ ] **Step 2: Run** `kit/bin/kit tools run bats tests/jq.bats`; expect FAIL.
- [ ] **Step 3: Implement `model::build`**. The narrowing order is `many` ⊃ `some`, `many` ⊃ `option`, `some` ⊃
  `one`, `option` ⊃ `one`; an enum narrows to a subset. Apply the release's files, then the repository's in path order.
- [ ] **Step 4: Run** the jq tests on jq on PATH and on jq 1.7 (`tests/jq.bats` does both); expect PASS.
- [ ] **Step 5: Commit** `#597 model: merge the repository's additions into the release's, narrowing and never widening`.

### Task 3: The structural checks

**Files:**

- Modify: `kit/modules/jq/model.jq`, `tests/jq/model.test`

**Interfaces:**

- Consumes: `model::build`'s output.
- Produces: `model::check` takes that output and returns the array of finding strings (the merge's included), empty
  when the model holds.

- [ ] **Step 1: Write jq tests**, each a model of two or three entities and the findings it gives: `a relation whose
  inverse is missing`; `an inverse that names another relation back`; `an inverse whose target is not the source`; `a
  self-relation is its own entity's inverse and passes` (`Organization.parent` ↔ `Organization.children`);
  `a type that names no entity or scalar`; `a sum variant that names no entity`; `a relation into a sum with a variant
  that has neither inverse nor derivation`; `ordered on a one`; `a held field with no read-by`; `a derived field with no
  from`; `a derived relation with an inverse`; `a stub with fields`; `a relation to a stub passes and the stub is
  counted` (output has a finding-free result and `model::stubs` returns the names).
- [ ] **Step 2: Run** the jq tests; expect FAIL.
- [ ] **Step 3: Implement `model::check` and `model::stubs`** (`model::stubs` takes the build output and returns the
  stub entity names, sorted).
- [ ] **Step 4: Run** the jq tests; expect PASS.
- [ ] **Step 5: Commit** `#597 model: check that every relation has its other side, and every type is known`.

### Task 4: The `kit model check` verb

**Files:**

- Create: `kit/bin/kit-model`; `projects/tui/internal/syntax/testdata/model.json` and
  `projects/tui/internal/form/testdata/model.golden` (both written by `bin/contracts`)
- Modify: `tests/model.bats`, `tests/help.bats` (the group listing, as the commit that added `kit platform` did),
  `docs/model.md`, `docs/features.md`, `bin/ci` (run `kit/bin/kit model check`)

**Interfaces:**

- Produces: `kit model check` prints each finding on its own line and `model: N entities, M stubs` last; exits 0 with
  no findings, 1 with any. The header's usage line is `kit model (check | table (--entity=<name> | --domain=<name>) |
  svg (--domain=<name> | --overview))`, group `files`.

- [ ] **Step 1: Write bats tests:** `check passes the release's model`; `check names a finding and exits 1` (a
  fixture repository with `.kit/model/code/bad.yml` whose relation lacks its inverse); `check counts stubs`; `an
  unknown subcommand exits 2 and says to run kit help model`.
- [ ] **Step 2: Run** the bats file; expect FAIL.
- [ ] **Step 3: Implement `kit/bin/kit-model`** after `kit-people`'s shape: header with usage, description, arguments,
  exit statuses, `guard:arguments model "$@"`, `use model` then `model:load | jq -L "${kit_root}/modules/jq" …`.
- [ ] **Step 4: Run** `bin/contracts`, then the bats file and `kit syntax --check`; expect PASS, and review the three
  new snapshot files.
- [ ] **Step 5: Commit** `#597 kit model check: the model's checks as a verb, and in the gate`.

### Task 5: Tables

**Files:**

- Modify: `kit/modules/jq/model.jq`, `kit/bin/kit-model`, `tests/jq/model.test`, `tests/model.bats`, `docs/model.md`

**Interfaces:**

- Produces: `model::fields($entity)` and `model::relations($domain)` each take the build output and return markdown
  text. `kit model table --entity=<name>` prints a fields table: columns `Field | Type | Arity | Source | Status |
  Read by | Means`. `kit model table --domain=<name>` prints a relations table: `Relation | To | Arity | Ordered |
  Inverse | Means`, one row per relation of every entity of the domain, sorted by entity then relation, with `Arity`
  as `1`, `0..1`, `0..*`, or `1..*`.

- [ ] **Step 1: Write jq tests** with exact expected text for one entity with a held, a planned, and a derived field,
  and for a domain with a one-to-one, a self-relation, and an ordered many.
- [ ] **Step 2: Run** the jq tests; expect FAIL.
- [ ] **Step 3: Implement both functions and the `table` subcommand.** An unknown entity or domain exits 2 and names the
  known ones.
- [ ] **Step 4: Write and run** a bats test that a `kit:generate` region calling `kit model table --entity=Worktree`
  is current after `kit generate` and stale after the model changes; expect PASS.
- [ ] **Step 5: Commit** `#597 kit model table: an entity's fields and a domain's relations, with arity`.

### Task 6: Diagrams

**Files:**

- Create: `kit/modules/jq/modelsvg.jq`, `tests/jq/modelsvg.test`
- Modify: `kit/bin/kit-model`, `tests/model.bats`, `docs/model.md`

**Interfaces:**

- Produces: `modelsvg::domain($name)` and `modelsvg::overview` take the build output and return the SVG text.
  `kit model svg --domain=<name>` and `--overview` print it.

The look is the one of the SVGs under `docs/entities/` today: a card per entity (name on a tinted band, `means`,
fields' count by status, a green or hollow dot), the same colors per domain, white background, `<title>` and `<desc>`.
What is new: an arrow runs between two cards for a pair of inverse relations, with the arity of each end written beside
it as `1`, `0..1`, `0..*`, `1..*` (and `{ordered}`), the relation names on the line, a sum card lists its variants, a
native card says `native: <tool>` and a logical card `logical`, a stub is dashed grey.

- [ ] **Step 1: Write jq tests:** `a domain's output is well-formed XML` (pipe to `xmllint --noout` in the bats test, a
  string check in jq), `every entity of the domain has a card`, `a pair of inverse relations is one arrow with both
  arities`, `a sum lists its variants`, `a stub is dashed`, `the output is the same on a second run`.
- [ ] **Step 2: Run** the jq tests; expect FAIL.
- [ ] **Step 3: Implement the layout:** a card goes in the column given by `layout` in `domain.yml`, or else one
  column right of the deepest entity that points to it (a breadth-first layering over `one`/`some` relations, ties by
  name), rows by name within a column. Text width is a per-character table, as the existing generator's; sort every
  object by key before output.
- [ ] **Step 4: Write a bats test** that `LC_ALL=C` and `LC_ALL=en_US.UTF-8` give identical bytes, and that
  `kit generate --check` is not involved (SVGs are files, not regions): `kit model svg --domain=code | cmp - docs/
  entities/code.svg` is the stale check, run in Task 11. Run all; expect PASS.
- [ ] **Step 5: Commit** `#597 kit model svg: a diagram of a domain, arrows with arity at both ends`.

### Task 7: The content of Code and git: objects

**Files:**

- Create: `kit/modules/model/code/domain.yml`, `kit/modules/model/code/` files for `GitBlob`, `GitTree`,
  `GitTreeEntry`, `GitCommit`, `GitSignature` (the author and committer line: name, email, time, offset), `GitMessage`,
  `GitTrailer`, `GitTag` (annotated), `GitObjectSignature` (the `gpgsig` and a tag's signature)

**Interfaces:**

- Consumes: the file format above and `kit model check`.
- Produces: the names above as native entities (`layer: native`, `tool: git`), which Tasks 8 and 9 relate to.

- [ ] **Step 1: Write each entity from git's format documents** (`gitformat-signature`, `gitformat-pack`, the object
  headers `git cat-file` prints) at the git version `.kit/` pins. Every header and field git stores is a field; `status:
  held` only where a verb prints it, with `read-by`. Arities as the design's: a commit has one tree, ordered `many`
  parents with inverse `children`, one author, one committer, `option` signature, one message; a tree has `many`
  entries; an entry is one of blob, tree, symlink, commit (a sum `GitTreeTarget`); a tag object has one target (a sum of
  the four object kinds), one tagger, `option` signature.
- [ ] **Step 2: Run** `kit/bin/kit model check`; expect no findings, and stubs only where Task 9 will fill.
- [ ] **Step 3: Run** `kit model table --entity=GitCommit` and read it against `git cat-file -p HEAD`; every header
  shown there has a row.
- [ ] **Step 4: Commit** `#597 model: git's objects, unpacked`.

### Task 8: The content of Code and git: refs, index, config, worktrees

**Files:**

- Create: `kit/modules/model/code/` files for `GitRef` (a sum of branch, remote-tracking, tag, note, stash, and the
  symbolic HEAD), `GitReflogEntry`, `GitIndex`, `GitIndexEntry` (mode, blob, conflict stage 0 to 3, stat data),
  `GitRemoteConfig` (name, url, pushurl, fetch refspecs, tagopt), `GitBranchConfig` (upstream remote and merge ref,
  rebase, description), `GitWorktreeAdmin` (`gitdir`, `HEAD`, `index`, `commondir`, locked and its reason), `GitSubmodule`

**Interfaces:**

- Consumes: Task 7's entities (a ref points to a `GitObject` sum; an index entry to a `GitBlob`).
- Produces: the native names Task 9's logical entities are `over`.

- [ ] **Step 1: Write each entity** as in Task 7, from `gitrepository-layout`, `git-config`, `gitsubmodules`, and
  `git worktree` documentation. A ref that points to an object has `one` target; HEAD is `GitHead`, a sum of `symbolic
  (GitRef)` and `detached (GitCommit)`.
- [ ] **Step 2: Run** `kit/bin/kit model check`; expect no findings.
- [ ] **Step 3: Commit** `#597 model: git's refs, index, configuration, and worktree files`.

### Task 9: The content of Code: kit's entities

**Files:**

- Create: `kit/modules/model/code/` files for `Organization`, `Repository`, `Remote`, `Checkout`, `Worktree`, `Head`,
  `Branch`, `Commit`, `Tag`, `Change`, `Review`; `kit/modules/model/platform/domain.yml` and `service.yml` (`stub: true`);
  a stub for the forge's native change (`ForgeChange`, in `kit/modules/model/code/`)

**Interfaces:**

- Consumes: Tasks 7 and 8's natives, by `over`.
- Produces: the logical Code model. Relations, with arity on each side:
  `Worktree.head` one `Head`; `Head` a sum `OnBranch(branch: Branch)`, `Detached(commit: Commit)`; `Branch.worktree`
  option, derived from the heads; `Checkout.main` one `Worktree` (`option` when bare), `Checkout.linked` many;
  `Checkout.repository` option, `Repository.checkouts` many; `Remote.repository` one, `Repository.remotes` some;
  `Repository.organization` one, `Organization.repositories` many, `Organization.parent` option, `Organization.children`
  many, `Organization.service` one `Service`, and `kind` `{enum: [user, organization, group]}`; `Branch.tip` one
  `Commit`, `Branch.upstream` option `Branch`; `Commit.parents` ordered many; `Tag` over `GitTag` and `GitRef`;
  `Change.branches` many `Branch`, `Change.bases` many `Branch`, `Review.change` one `Change`.
  Each logical field a verb prints is `held` with `read-by` (`workspace repos organization`, `workspace commits issue`,
  and the rest of the keys in `kit workspace --json`, `kit flow --json`).

- [ ] **Step 1: Write the entities and `domain.yml` for code** (name, intro, layout hints as the existing SVG's grid).
- [ ] **Step 2: Run** `kit/bin/kit model check`; expect no findings and exactly the stubs `Service` and `ForgeChange`.
- [ ] **Step 3: Run** `kit model table --domain=code` and read each relation against the design's arity list; every
  line there appears.
- [ ] **Step 4: Commit** `#597 model: Code, with Organization, and arity on every relation`.

### Task 10: The model held to reality

**Files:**

- Create: `tests/model-reality.bats`, `tests/fixtures/model-repo/` (a script that builds the fixture repository)

**Interfaces:**

- Consumes: the whole model of Tasks 7 to 9.

- [ ] **Step 1: Write the fixture builder** that makes a repository with a root commit, a merge, a signed commit, an
  annotated tag, a signed tag, a submodule, a symlink, a detached linked worktree, a locked worktree, and a remote with
  a push URL.
- [ ] **Step 2: Write the tests:** `every header of every object in the fixture is a field of its entity` (walk `git
  rev-list --all --objects`, read each with `git cat-file -p`, take the header names, assert each is a field of the
  matching native entity); `every key of every config section the fixture sets is a field`; `every held field's
  read-by names a verb that prints the key` (for each, run the verb in a fixture workspace with `--json` and assert the
  key is present in a row); `no held field names a verb that does not exist`.
- [ ] **Step 3: Run** `kit/bin/kit tools run bats tests/model-reality.bats`; fix the model (not the test) for each
  failure, until PASS.
- [ ] **Step 4: Commit** `#597 model: tests that hold git's objects and kit's rows to the model`.

### Task 11: The generated pages

**Files:**

- Create: `docs/entities/code.md`, `docs/entities/README.md`
- Modify: the Code SVG under `docs/entities/`, replaced with the output of `kit model svg --domain=code`; the other
  domains' SVGs stay until their pass
- Modify: the Code section of `docs/superpowers/specs/2026-11-09-entities-design.md`, which links
  `docs/entities/code.md`; `docs/features.md`; `bin/ci`, which compares the Code SVG with the verb's output

**Interfaces:**

- Consumes: `kit model table` and `kit model svg` of Tasks 5 and 6, and the Code model of Tasks 7 to 9.
- Produces: `docs/entities/code.md`, which a later domain's pass copies for its own page.

- [ ] **Step 1: Write `docs/entities/code.md`** with the diagram and, per entity, a `kit:generate` region calling
  `kit model table --entity=<name>`, and one region for `kit model table --domain=code`; `README.md` lists the pages.
- [ ] **Step 2: Run** `kit generate docs/entities/code.md`, then `kit generate --check`; expect current.
- [ ] **Step 3: Add the stale check to `bin/ci`:** for each domain with a pass, `kit/bin/kit model svg
  --domain=<name> | cmp -s - docs/entities/<name>.svg`.
- [ ] **Step 4: Run** `kit gate`; expect it to pass, including the lychee links.
- [ ] **Step 5: Commit** `#597 docs: the generated Code pages, and the gate holds them to the model`.

---

**Self-review (done against the spec).** Coverage: relationship arity, sums, Organization, deep git data (Tasks 7 to 9),
layers and stubs (3, 9), extension rule (2), checks (3, 4), tables and diagrams from the model (5, 6, 11), a
real-repository test and held-field sources (10), `kit model` in the release (4), `domain.yml` (1, 6, 9), replacing hand
SVGs for Code (11). The other domains' SVGs stay hand-made until their pass, which the spec's first pass allows. The
spec's "one file per entity, extension in files of its own" is Tasks 1 and 2.
