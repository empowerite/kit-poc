<!-- kit:generated -- the entry every agent reads first, from the kit package -->
<!-- see: "Changing what kit adds" below, to replace it -->
# Read this first

This file is the kit's entry point. Every agent follows it in every session, in any repository that has a `.kit/`
directory. The repository's own rules in `AGENTS.md` apply as well. Where the two differ, `AGENTS.md` wins.

## Integrity

1. Report only what happened. Write "done", "passing", or "verified" only for something that ran and succeeded.
2. Report a skip as a skip. A check that was not run, is not implemented, or cannot be implemented is reported as
   exactly that. It passes no gate and earns no credit.
3. Give the evidence for every claim, or say there is none. Name the command that ran and what it printed.
4. Being wrong is recoverable. Misreporting is not.
5. Rules live in the repository, never in a session's memory. When you learn a convention or receive a correction,
   write it down, through the workflow, in one of these places, where every agent and every person reads it:
   - `AGENTS.md`
   - a package of the repository's own under `.kit/packages/`
   - a kit release

## The root checkout is the human's desk

The desk is the root checkout on the human's machine, on whatever branch it currently has. It belongs to the human.
They type, review, and leave work in progress there. It usually has `main` checked out, and may have any branch that
no worktree has checked out.

An agent never checks out, resets, rebases, or otherwise changes the desk in place. An agent works in a worktree,
which `kit work` makes. Work reaches the default branch only through a merged pull request.

Uncommitted work on the desk is the human's to move. At a terminal, `kit work` sweeps it into the new worktree. An
agent runs `kit work --no-sweep <N>`, which leaves it on the desk, and gives `--sweep` only when the human asks for
that work to be moved. Without a terminal and without either flag, `kit work` refuses a desk that has uncommitted
work, and names both. The `work` tool of `kit serve` never sweeps.

## The workflow

How work moves from an issue to a merged pull request is the repository's to say. With the `workflow` package active,
`.kit/workflow.md` says it, and an agent follows it as it follows this file. Without it, `AGENTS.md` says it.

## Kit commands instead of git commands

Some git commands have a kit replacement that adds the check its rule requires. An agent uses only the kit
command. Claude Code and Gemini CLI, with the kit's agents package, refuse the raw git command by its literal pattern.
Elsewhere, this rule is the only thing that stops it.

- `kit rebase`, never `git rebase`. `kit rebase` refuses to run on the default branch.
  Otherwise it rebases the worktree's branch onto the default branch at the primary remote, `origin` unless
  `primary` in `kit.yml` names another, and pushes it.
- `kit commit`, never `git commit`. `kit commit` refuses the default branch, runs the linters over the
  staged paths, refuses a path the kit placed, and holds the subject to the policy before the commit exists. Its message
  is an option written in full, as the whole command shows: `git add <path>… && kit commit --message='<subject>'`.
- `kit submit`, never `git push`. `kit submit` pushes the branch, and commits nothing: what is staged stays staged,
  for `kit commit`. It never forces: when the remote has moved, it names `kit rebase`.
- `kit work`, never `git worktree add`, `git checkout -b`, or `git switch -c`.
- `kit tidy`, never `git worktree remove` or `git branch -D`.
- An agent never switches or resets the desk. `git checkout main`, `git switch main`, `git reset --hard`, and
  `git push --force` are on the same deny list. It names `main` literally.
- An agent never merges: `gh pr merge`, `glab mr merge`, `az repos pr update`, and `git merge` are on the same deny
  list. A person merges, after review.
- An agent never discards or hides work on the desk or in a worktree: `git restore`, `git clean`, and `git stash` are
  on the same deny list.
- An agent never runs `kit trust --clone`, which is on the same deny list. The trust is the person's to give. When kit
  answers that it runs nothing in a clone until you trust it, the agent stops and asks the person to run `kit trust --clone`
  in a terminal.

These limits do not apply to the human at the desk.

## Rules by file type

Each kind of file is defined under `.kit/kinds/`, by its `name:`: the path globs and first-line patterns that make a
file of that kind, and the kinds found inside its files, such as the bash in a justfile. A kind may have a rule file
under `.kit/rules/`; `any`, `text`, and `yaml` have none of their own. A rule says what the work must do to be
trusted. A style file under `.kit/styles/`, from a style package, says how the file looks. Rule files and style
files have the same frontmatter, with these keys:

| Key | Contains |
| --- | --- |
| `kind:` | The kinds of file it governs, by name. |
| `lint:` | The linter that `kit lint` runs over the files it governs. |
| `checks:` | The kit's own checks that `kit lint` runs over the files it governs, by name. |
| `templates:` | The shapes a file of this kind can take. The templates are under `.kit/templates/`. |

A rule or style governs every file of a kind it names, and `kit kinds <path>` prints the kinds a file is of.
`kit context` prints the rules of every kind a file is of, then the rules of the kinds those kinds embed, so a
justfile brings the bash rule with it. `kit lint` does not follow embeds, so no linter runs over a file it cannot
parse.

Before you change a file:

1. Run `kit context <path>`. It prints the rules, then the style, that govern the file, and records the path in a
   local log.
2. Read every file it prints.

No agent keeps a copy of the rules. `kit context` is how every agent, and every person, finds them. Where the
agent has the kit's MCP server, `kit serve`, the rules are resources, starting at `kit://1st.md`, and the verbs are
tools in three groups: `context`, `flow`, `help`, `kinds`, `packages`, `syntax`, and `version` read only; `check`,
`lint`, `toolchains`, and `tools` run what the repository's files name; and `assign`, `close`, `gather`, `leases`,
`settle`, `unassign`, and `work` act on issues, their leases, and pull requests.

Where a template governs a new file, create it with `kit new file <path>`, giving the path from the repository
root, and never write it from nothing. `kit new file`:

- writes the file from its template
- fills the template's holes that the path supplies
- refuses a hole you left empty, and names the flag that fills it, such as `--purpose=<…>` or `--title=<…>`
- prints the rules to read before you write the rest of the file

Two flags choose the template:

- `--variant=<…>` picks another of the shapes, such as a sourced bash module.
- `--rule=<…>` names the rule or style for a path with no extension.

`kit lint` fails any file, including one written by hand, whose shape matches none of its templates.

`kit new` also makes a kind, a rule, a style, a template, a package, a bash module, or a provider (the code for one
forge, tracker, or toolchain), in a package or module directory of the repository's own. `kit help new` lists them.

| Kind | Rule |
| --- | --- |
| Markdown | [rules/markdown.md](rules/markdown.md) |
| Bash | [rules/bash.md](rules/bash.md) |
| POSIX shell | [rules/sh.md](rules/sh.md) |
| Just | [rules/just.md](rules/just.md) |
| Workflows | [rules/workflows.md](rules/workflows.md) |
| JSON | [rules/json.md](rules/json.md) |
| jq modules | [rules/jq.md](rules/jq.md) |
| Ignore lists | [rules/gitignore.md](rules/gitignore.md) |

## What the kit delivers

The repository commits what it declares, and every worktree holds the files kit places:

- `kit.yml`, committed: its `version:` and `packages:` declare the release and the active packages.
- `.kit/packages/`, committed: the repository's own packages.
- `.kit/presets/`, committed: the table views a team shares from `kit flow`.
- Everything else under `.kit/`, placed by `kit hydrate`: this file, the kinds, the rules, the styles from the
  style packages the repository takes, and the rest of what the packages deliver. Each is a link to its source
  when the source is inside the worktree, and otherwise a copy without the write bit. `.kit/.gitignore` names every
  one, so git never sees them.
- `.kit/manifest`, the digest of each delivered file, and `.kit/.gitignore` itself: written by kit, and ignored
  and without the write bit like the rest.

The installed release contains the code. You run it through the kit CLI, `kit` on `PATH`. The workflow commands are
`kit work`, `kit commit`, `kit submit`, `kit rebase`, `kit ready`, `kit tidy`, `kit flow`, `kit context`,
`kit new file`, `kit lint`, `kit gate`, and `kit hydrate`. Use them, not the git commands they replace, with the
options `kit help <verb>` lists.

A repository activates the packages it wants with `kit packages add <package>`. `kit packages` lists every package and
what it delivers, and `.kit/README.md` says how kit places each file.

## Changing what kit adds

Every file kit adds belongs to a package. A file under `.kit/` opens with a `kit:generated` line that names what it is
and its package, and a `see:` line that says how to stop using it or replace it. A template under `.kit/templates/`
is the exception: it holds the shape a new file starts as. It cannot be edited where it lies:
a link leads to its source, a copy has no write bit, and git never sees either. `kit check` fails when any
delivered file differs from the pinned release. Instead:

- To stop using a file, remove its package: `kit packages remove <package>`. It takes out everything the package
  added. A package that another active package depends on is refused until that one is removed. A member of a
  bundle such as `empowerite` can be removed on its own: kit records it as excluded, and `kit update` leaves it
  out.
- To replace a file, write a package of the repository's own under `.kit/packages/<name>/`. Its `package.yml`
  depends on the package that adds the file, and it places the replacement at the same path under `files/repo/`.
  Activate it with `kit packages add <name>`. The later package in dependency order wins, so the repository's file
  is used, and `kit update` still brings everything else from the next release.
- To fill in a value that a template asks for, set it under `answers:` in `kit.yml`.
- In a file kit shares with the repository, such as `AGENTS.md`, `.gitignore`, or `.claude/settings.json`, only
  the kit's region or the kit's entries are kit's. The rest of the file is the repository's to edit.
