# The entity model: data, arity, and layers

[The entities design](2026-11-09-entities-design.md) names kit's entities and says in a sentence what each one is. This
design makes that exact. Every entity lists the data one can explore in it, down to what git or a forge stores. Every
relationship says how many on each side, and whether a side is optional. Both live in data files, one per entity, and
the tables and diagrams in the docs are generated from them.

## Intent

The entities design says "has", "holds", and "contains", and a diagram built from it guesses the direction and the count
of each arrow. A worktree is on one branch, and a branch is on at most one worktree, and no page says so. A commit is
a hash and a subject in kit's rows, while git stores a tree, parents, an author and a committer with times, a
signature, and a message with trailers, each of which one can explore. Code has no Organization, though every
`kit workspace` row already carries one. When kittui, `kit flow --json`, a policy, and a provider contract each decide
for themselves what a commit is and how a worktree relates to a branch, they disagree.

One model, written once and checked, is what they read. The people it serves are the ones who build kit's verbs,
kittui's tabs, and providers, and an organization that adds fields and entities of its own.

## Goals

- Every relationship is declared as two directed functions, one per direction, each with an arity: exactly one, at most
  one, any number, or at least one, and ordered where order matters. `Worktree.head` is exactly one head, and
  `Branch.worktree` is at most one worktree.
- A value that is one of several kinds is a sum type, declared once. A worktree's head is a branch or a detached
  commit, because git allows both.
- Every entity lists every field its tool stores, unpacked into entities where a field has parts of its own: a commit
  has a tree, parents, an author, a committer, a signature, and a message, and a message has a subject, a body, and
  trailers.
- Each field says where its value comes from (stored by the tool, or derived from other data) and where kit stands
  with it (held now, planned, or in the world but unused by kit).
- Each entity says which layer it is in. A native entity is one a tool stores: a git commit, a GitHub pull request. A
  logical entity is kit's own, defined over natives: a Checkout, a Change, a Repository.
- An organization can add fields, relationships, and entities of its own to the model, and cannot take away or loosen
  what the release defines.
- A check holds the model to itself: every relationship has its other direction with a compatible arity, and no
  relationship, field type, or inverse names an entity that does not exist.
- The tables and the diagrams in the docs are written from the model, and a check fails when they are stale.

## Non-goals

- Generating code from the model. The model describes; verbs and kittui keep their own code. A later design may
  generate row schemas from it.
- Modelling every field of every tool in the first pass. The first pass is Code and git. The forge's native entities,
  the trackers, and each other domain follow, one at a time, in the same format.
- A query language over the model, or storing instances of entities. kit keeps no state about the platform.
- CUE in the first pass. The files are shaped so that a move to CUE is a rename and a schema, not a rewrite.

## Anti-goals

- A second description of an entity that can differ from the first. If a table or a diagram can be edited by hand and
  differ from the model, the design has failed.
- A relationship with arity on one side only.
- A "misc" or "other" bucket that lets an unmodelled field through. A field either is in the model or is unmodelled,
  and the model says which.
- A customization that changes what the release's entities mean for everyone who reads them.

## Constraints

- The release is `kit/`, and everything in it is written for a consumer. The release's model files ship in it, and a
  consumer's additions live in the consumer's repository.
- Formats stay as kit's are: YAML for files people write, JSON for what verbs print. A model file uses only the part
  of YAML that CUE also reads, so a later move needs no change to the files.
- A markdown page that shows generated tables holds them in `kit:generate` regions, so `kit generate --check` and
  `kit check` already hold them to the model.
- The checks run where kit's other checks run: on a desk, in `kit lint` or `kit check`, and in CI.

## Terms

- An entity is a kind of thing with an identity: Commit, Worktree, Organization.
- A field is a value an entity carries, with a type: a scalar, an enumeration, another entity, or a list of them.
- A relation is a directed function from one entity to another, with an arity. Two relations that name each other as
  their inverse describe one relationship.
- An arity is one of `one` (exactly one), `option` (zero or one), `many` (zero or more), and `some` (one or more). A
  `many` or `some` is `ordered` when its order is part of the data, as a commit's parents are.
- A sum is a value that is one of a named set of variants, each with its own entity or fields.
- A layer is `native` (a tool stores it, and the entity names the tool) or `logical` (kit defines it over natives).
- A derivation says a field or a relation is computed from other data and stores nothing: a branch's `ahead` count, a
  commit's signature check, a branch's worktree through the heads of the worktrees.
- A status says where kit stands with a field: `held` (a verb reads it today), `planned` (the entities design names it),
  or `unused` (the tool stores it and kit does not read it).

## The shape of a model file

One file holds one entity. Directories group the files by domain, as the entities design does:

```text
model/code/commit.yml
model/code/worktree.yml
model/code/branch.yml
model/code/head.yml          # a sum
model/code/organization.yml
model/work/issue.yml
```

A file names the entity, its layer, what it is, its fields, and its relations. This is the shape; the key names are the
builder's, and the example is not the final content:

```yaml
entity: Worktree
layer: logical
over: [git worktree]
means: a working directory with its own HEAD and index, linked to one checkout
fields:
  path:    {type: Path,     source: stored,  status: held}
  locked:  {type: LockInfo, arity: option, source: stored, status: unused}
  prunable: {type: Bool,    source: derived, status: unused}
relations:
  head:     {to: Head,     arity: one,    inverse: Head.worktree}
  checkout: {to: Checkout, arity: one,    inverse: Checkout.worktrees}
```

```yaml
entity: Head
sum: true
means: what a worktree is on, which git lets be a branch or a bare commit
variants:
  OnBranch: {branch: Branch}
  Detached: {commit: Commit}
```

```yaml
entity: Branch
relations:
  worktree: {to: Worktree, arity: option, derived: "the worktree whose head is OnBranch(this)"}
  tip:      {to: Commit,   arity: one, inverse: Commit.tipped-by}
  upstream: {to: Branch,   arity: option}
```

A relation names its inverse, or says it is derived and from what. Any pair of arities is a valid relationship: `one`
against `option` is a one-to-one that may be unpaired on one side, `one` against `many` is a one-to-many, and `many`
against `many` is a many-to-many. So the check does not rule on arities. It rules that the inverse exists and names the
relation back, that each side's target is the other side's entity, and that `ordered` is set only where the order is
the data. A relation into a sum declares an inverse for each variant's entity, or a derivation that says how the
variant's entity reaches the source: `Worktree.head` is a `Head`, and `Branch.worktree` is derived from the worktrees
whose head is `OnBranch` with that branch.

### Layers and extensions

The release's files define the core model. An organization adds files in its own repository: a new entity, a new field
on a core entity, a new relation. A file that adds to a core entity says `extends: Commit` in place of `entity:`, and
holds only what it adds. A new entity may be defined only once, by one file.

An addition may add, and may narrow. To narrow is to accept a subset of what the core accepts: an arity from `many` to
`some` or `option`, from `some` or `option` to `one`; an enumeration to some of its values; a scalar to a stricter
scalar. It may not remove a core field or relation, change a type to one that is not narrower, or widen an arity. A
status and a layer are the release's to say. Every reader of a core entity can then rely on it. This is the rule
settings follow in
[the entities design](2026-11-09-entities-design.md#configuration): an organization tightens what the release says and
never loosens it. In CUE this rule is unification, which is why CUE is the intended end point.

### One file per entity

A single file for the whole model grows to thousands of lines and cannot be extended without editing it. A file per
domain still makes an extension edit a shared file. A file per entity lets an organization add a file or replace none,
lets a review of the model read one entity, and puts a relationship's two sides in the two files they describe. A
domain is a directory, not a unit of ownership.

## The first pass: Code and git

The first pass writes the model for git's own objects and for kit's entities over them.

A native entity and a logical one that share a word are two entities. The native one takes the tool's name where the
two collide: `GitTag` is the annotated tag object git stores, `Tag` is kit's entity over a ref and the object it
reaches, and `Tag` names `GitTag` in its `over`. A logical entity lists the natives it is defined over, and a field
of it that is a native's field says which.

A relation may name an entity of a domain that is not yet modelled. That entity has a file with `stub: true`, which
names it and says what it is and holds no fields. A stub is shown as one in the tables and the diagrams, and the check
counts the stubs, so an unmodelled domain is visible. Organization's service is `Service`, a stub in Platform until
that domain's pass.

Native to git: Blob, Tree and its entries (a mode, a name, and a blob, a tree, a symlink, or a submodule's commit),
Commit, Signature (an identity and a time with its offset), Message with its subject, body, and trailers, the
signature a commit or a tag carries, annotated Tag, Ref in each kind (branch, remote-tracking, tag, note, stash, HEAD),
Reflog entry, Index with its entries and conflict stages, Remote and branch configuration, the worktree's
administrative files, and Submodule.

Logical to kit: Organization, Repository, Remote, Checkout, Worktree, Head, Branch, Tag, and the rest of Code. The
Change and the Review are kit's names for forge entities, and their native side comes in the forge pass.

Arity the first pass settles, among others:

- A commit has exactly one tree, an ordered list of parents (none for a root, two or more for a merge), exactly one
  author, exactly one committer, at most one signature, and exactly one message.
- A tree has any number of entries, each naming exactly one blob, tree, symlink, or commit.
- A worktree has exactly one head, a branch or a detached commit. A branch is on at most one worktree.
- A checkout has exactly one main worktree, or none when it is bare, and any number of linked worktrees.
- A repository is named by a remote's URL, so a checkout with no remote has no repository. A checkout has at most one
  repository, and a repository has any number of checkouts on a machine.
- A repository has exactly one organization. An organization has any number of repositories, at most one parent
  organization, and a kind (a user, an organization, a group). Azure DevOps puts a project between the organization
  and the repository, and GitLab nests groups, so the parent relation is a chain, and the organization belongs to one
  service.

## Complete, and true

Complete means every field in git's own format documents (`gitformat-*`, `gitrepository-layout`, and the object
headers `git cat-file` prints), for the git version kit's toolchain pins. A field git stores and kit does not read is
`unused`, never left out.

Two tests hold the model to reality, in the repository's test suite. One builds a fixture repository that has every
case the model names (a root commit, a merge, a signed commit, an annotated and a signed tag, a submodule, a symlink, a
detached worktree, a locked worktree, a remote with a push URL) and walks its objects with `git cat-file`: an object
header or a config key the model does not name fails the test. The other takes each `held` field's named source, the
verb and the JSON key that prints it, and fails when the verb does not print it. A `held` field therefore always names
that source.

## Checks and generation

- Each domain directory holds a `domain.yml`: the domain's name, its intro, and layout hints for its diagram (which row
  and column an entity prefers). The hints are optional; without them the layout puts an entity below the entities
  that point to it.
- A release verb, `kit model`, runs the checks and writes the tables and the diagrams. It ships because an
  organization's additions need it: the organization's own pages hold its tables in `kit:generate` regions that call
  the verb, and `kit model svg` writes a diagram to a path the caller names. The verb reads the release's files and
  the repository's additions together.
- The checks and the tables are bash, jq, and yq, as kit's other modules are, and read YAML through `yaml.sh`. The
  diagram's layout must be deterministic, so the stale check can compare bytes. It is written in jq and bash, or in
  the Go of the `kittui` binary the release already ships; which is the builder's call.
- The SVGs under `docs/entities/` today are written by hand. The generated ones replace them whole, and the pages under
  `docs/entities/` are new.
- A check over the model: a relation's inverse exists and its arity is compatible; every type names an entity, a sum,
  or a scalar; a sum's variants name entities; an extension does not remove or loosen a core definition; a derived
  field names what it derives from.
- Generated tables, in `kit:generate` regions of the pages under `docs/entities/`: one per entity for its fields and
  one per domain for its relations, with arity.
- Generated diagrams, the SVGs under `docs/entities/`, one per domain and one overview: entities as cards, relations as
  arrows with their arity at each end, the layer and the status shown. A check fails when a diagram differs from what
  the generator writes.
- The entities design links to the generated pages and keeps the prose, the reasons, and the open questions.

## Approaches

1. One model file for the whole model. Simple to read, and it cannot be extended without editing the release's file.
   Rejected.
2. One file per domain. A relationship's two sides sit together, and an extension still edits a shared file. Rejected.
3. One file per entity, in a directory per domain, with the release's files plus the consumer's. An extension adds a
   file, a review reads one entity, and the check joins the two sides of a relationship. Chosen.

For the format:

1. Data files with a bash, jq, and yq checker and generator, shaped for CUE. Chosen: it needs no toolchain kit does not
   ship, and the checks are short.
2. CUE from the start. Stricter, and the extension rule is native to it, but it adds a tool to every desk and to CI.
   The intended end point; the files are written so that moving to it is a rename and a schema.
3. Hand-written tables and hand-edited SVGs, as now. Nothing stops the two from drifting. Rejected.

## What is left to the builder

- The key names of a model file, and the exact YAML shape of arity, ordering, sums, and derivations.
- The layout algorithm of the diagrams, and the language it is written in.
- Where the release's files sit (`kit/model/`, or elsewhere in `kit/`), and where a consumer's additions sit.
- The layout of the generated pages and how an arity is drawn at each end of an arrow.
- The full inventory of git's fields, written from git's own format documentation and from the objects of a real
  repository.
- How a field that a forge or tracker holds, such as a pull request's `mergeable`, is recorded as native to that tool.

## My calls

- Deep means git's own storage: the model unpacks what `git cat-file` shows, and a field says whether kit reads it.
- A worktree's head is a sum of a branch and a detached commit, because git allows both.
- One file per entity, a directory per domain, with a consumer's additions in files of its own.
- An addition may add and narrow and may not remove or loosen, the rule settings already follow.
- YAML now, shaped for CUE, which is the intended end point.
- The first pass is Code and git; the forge's native entities and each other domain follow in the same format.
- A native entity that collides with a logical one is named for its tool, and a logical entity says what it is over.
- An addition is an `extends:` file, and narrowing is accepting a subset, as CUE unification does.
- Any pair of arities is valid; the check rules on the inverse, the types, and the order flag.
- Complete means git's documented formats at the version kit pins, held to a real repository by a test, and each `held`
  field names the verb and key that prints it.
- `kit model` ships in the release, because an organization's additions need it, and the tables and checks are bash,
  jq, and yq.
- An entity of a domain not yet modelled is a stub, counted and shown.
