# Workspaces

A workspace is what kit looks at: one repository, or a named group of repositories that move together. Started
inside a repository, kit looks at that repository. A group lets you see several repositories at once, without opening
each one.

This page has three parts:

- [Tasks](#tasks) shows how to make a group, use it, and look across it.
- [Reference](#reference) describes the file, the members, the rule for which workspace kit starts on, and the
  options.
- [kittui and workspaces](#kittui-and-workspaces) describes the three screens that work with groups.

Some words of this page:

| Word | Meaning |
| --- | --- |
| member | one repository of a group, named by its host and its whole path |
| checkout | a clone of a member on your machine |
| desk | the root checkout of a repository, where you cloned it |
| linked worktree | a second checkout of a repository, on a branch of its own |

## Tasks

### Make a group

```sh
kit workspaces --new=empowerite . github.com/empowerite/edge
```

`--new` takes a name and the repositories that join the group. A repository is a member name, a git URL, or the
folder of a checkout. `.` is the repository you are in.

To add many repositories at once, give `--new` or `--add` a pattern, a command, or both:

```sh
kit workspaces --new=brew 'github.com/empowerite/homebrew-*'      # the checkouts under your roots that match
kit workspaces --add=org --from="gh repo list empowerite --limit 1000 --json url --jq '.[].url'"
kit workspaces --remove=org 'github.com/empowerite/attic-*'       # the group's members that match
```

- A pattern is a member that holds `*`, `?`, or `[`.
- `--from=<command>` is a command that kit runs with bash. Each line it prints is a repository.
- kit writes the members it found under `repos`, as if you had named each one. The group does not follow the pattern
  or the command afterward, so it does not pick up new repositories later.

### Change a group

```sh
kit workspaces --add=empowerite github.com/empowerite/edge
kit workspaces --remove=empowerite github.com/empowerite/edge
kit workspaces --rename=empowerite core           # the group keeps its place, its comments, and its favorite
kit workspaces --delete=core                      # the group goes; its checkouts stay as they were
kit workspaces --favorite=empowerite
kit workspaces --unfavorite=empowerite
```

Each command that edits the file prints one line. The line says what changed, or that nothing needed to change, such
as `📚 empowerite holds them already`. These commands take no `--json`.

### Look at your groups

```sh
kit workspaces                                    # the groups and the favorites
kit workspaces --show=empowerite                  # each member, with its checkout or ☁️
kit workspaces --current                          # the workspace kit starts on here, and why
```

Every form that reads prints JSON with `--json`. `kit help workspaces` gives the shapes.

### Choose where kit starts

```sh
kit workspaces --use=empowerite                   # start on empowerite outside a repository
kit workspaces --use=.                            # keep the repository here among the recent ones
```

See [Which workspace kit starts on](#which-workspace-kit-starts-on) for the rule.

### Look across a group

```sh
kit --workspace=empowerite flow                   # each cloned member's picture, under its member's name
kit --workspace=empowerite flow issues --json     # every member's open issues, each row with its member
kit --workspace=empowerite platform settings      # one stage of an app verb, in every member
kit --workspace=empowerite workspace repos        # each member: its forge, branch, and checkout, or not cloned
kit --workspace=empowerite workspace commits      # the commits not on the default branch, in every member
kit --workspace=empowerite welcome --checks       # each member's desk and worktrees, checked in the group's order
```

`--workspace=` is an option of `kit` itself, so it goes before the verb. It runs the verb in the checkout of every
cloned member at once. Each member's checkout uses its own `kit.yml`, so a GitLab member beside GitHub members keeps
its forge and its trackers.

On a terminal, `kit --workspace=empowerite flow` opens the Flow app of kittui over the group. The other apps follow
the same group. Every tab gathers the rows of every cloned member, grouped by member as they load. A member that kit
could not read is one red line among the rows.

### Look at git across a group

`kit workspace` prints what git holds: the members, then remotes, branches, worktrees, commits, and tags. It reads
only git and asks no remote, so what a remote has is what your last fetch left.

```sh
kit workspace                                     # the repository here: every stage
kit workspace branches                            # its branches, local and on each remote
kit workspace worktrees --json                    # {contract, rows, errors}, each row a worktree
kit --workspace=empowerite workspace repos        # each member of the group
```

- Without `--workspace=`, `kit workspace` reads the repository you are in. In a linked worktree, it reads the
  repository's main checkout.
- With `--workspace=`, every row gains `member`.
- `kit workspace` exits 1 when it cannot read a member, or a member's desk. It still prints what it read. The member
  is under `errors`, or the desk's line is the `error` of the member's `repos` row.
- On a terminal, `kit workspace` opens the Repositories app, with the repos tab first and the incoming tab last.
  `~` stands for the home folder in a clone's path. A closed row of the repos tab shows `…` and the last two folders
  of the path, and an open row shows the whole path. A member's name on any tab leads to its row on the repos tab.

[apps.md](apps.md#repositories-kit-workspace) lists the fields of every stage.

### Check the setup of a group

```sh
kit welcome --checks --json                       # the machine's checks, then each folder of the repository here
kit --workspace=empowerite welcome --checks       # each member's desk and worktrees, in the group's order
kit --workspace=none welcome --checks             # no group: the repository here, or the machine's checks alone
```

`kit welcome` checks each folder of the workspace on its own, because each branch can have a `kit.yml` or none, and
can pin a kit version of its own.

- For a repository, the folders are its desk, then each worktree that `git worktree list` names.
- For a group, they are the desk and worktrees of each member that has a checkout under your roots.
- Each folder's check names the folder, the repository, whether it is the desk, the branch, and the kit version that
  its `kit.yml` declares. `kit check` runs there, on the release that the folder pins.
- The machine's checks run once. They cover the tools that kit runs on, the machine's package manager, and the tool
  and the login of each forge host among the remotes of the folders.
- `kit welcome --fix=<check> --folder=<path>` runs the fix of one folder's check in that folder.

On a terminal, kittui's setup step draws the checks as one table. The machine's checks come first. Then each
repository has one row for each folder, with its branch, its kit version, and a column for each kind of check. Each
failed check shows under its row, with its fix. The members that have no checkout are named under the table. `kit help
welcome` describes the checks.

## Reference

### The file

Groups are yours alone. kit keeps them in `${XDG_CONFIG_HOME:-~/.config}/kit/workspaces.yml`. You can edit the file
by hand. When kit edits it, your comments stay where they were.

```yaml
# where your clones are; kit looks for checkouts here, four levels down
roots: [~/Code]
favorites: [empowerite]
workspaces:
  empowerite:
    repos:
      - github.com/empowerite/kit
      - github.com/empowerite/edge
      - git@github.com:empowerite/jig.git
    exclude: [github.com/empowerite/attic]
```

| Key | Meaning |
| --- | --- |
| `roots` | the directories that kit looks under for checkouts; `~` is your home directory, and a root written twice, as `~/Code` and `~/Code/`, counts once |
| `favorites` | the workspaces to keep at hand: each is a group's name or a repository |
| `workspaces` | your groups, by name |
| `repos` | in a group: its members |
| `exclude` | in a group: members to take back out |
| `sources` | the artifact sources that kit searches before the repository's, such as a mirror, and `off` behind a firewall |

`sources` is your layer of the pull path. It applies to every repository you work in. See
[packages.md](packages.md#kinds-and-the-pull-path).

A group's name starts with a lowercase letter or a digit. It holds only lowercase letters, digits, `.`, `_`, and `-`,
and never `/`. That is how kit tells a group's name from a repository.

#### What kit refuses

kit checks the file wherever it reads it. It refuses:

- a file that does not parse, or that is not a map
- a group with a key other than `repos` and `exclude`; `match` and `project` are not built yet
- a group whose name breaks the rule above, and a group named `none`
- an entry that names no repository

A command that reads a refused file says what is wrong, prints nothing else, and exits 1.

`kit workspaces` always reads the file. `kit flow`, `kit workspace`, and the app verbs read it only when they need a
group: with `--workspace=<name>`, or outside a repository when a last-used group is recorded. Inside a repository,
or with no group used, they read no file.

### Members and checkouts

A member is named by its host and its whole path: `github.com/empowerite/edge`, or `gitlab.com/group/sub/repo` on
GitLab. A git URL names the same member, so `git@github.com:empowerite/jig.git` is `github.com/empowerite/jig`.

kit spells a member one way: the host in lower case, and on GitHub and GitLab the path in lower case too. So
`github.com/NixOS/nixpkgs` is `github.com/nixos/nixpkgs`.

A member's checkout is a clone under one of your roots whose primary remote points at the member. The primary remote
is the `primary` setting in the clone's `kit.yml`, otherwise `origin`.

- A clone's other remotes never make it a checkout of another member. A fork's clone, with the original as `upstream`,
  counts once, under the fork.
- A member that you cloned twice has both clones as checkouts. kit uses the first, under the earliest root.
- A member with no checkout is still a member.
- A clone whose `kit.yml` does not parse names no primary. kit files it under `origin` and goes on walking your roots.
  kit says so where the member is drawn: a warning for the member's first checkout, and the `error` of its `repos` row.

A checkout is a directory that holds a `.git` directory. A bare repository, a linked worktree, and a clone behind a
symbolic link are not checkouts. kit does not look inside a hidden folder.

### Which workspace kit starts on

kit takes the first of these that applies:

1. The workspace that `--workspace=` gives. The option goes before the verb: `kit --workspace=empowerite flow`.
   `--workspace=none` names no workspace.
2. The repository you are in. This holds even when the repository belongs to a group. In a linked worktree, it is
   the repository that the worktree belongs to.
3. Outside any repository, the last group used.
4. With no group used yet, none.

A directory is inside a repository when it is in the repository's working tree, where `git rev-parse --show-toplevel`
answers. A bare repository has no working tree, and a `.git` directory is not in one. Both count as outside a
repository.

When kit starts on none:

| Command | What it does |
| --- | --- |
| `kit flow` | lists each repository that it finds under the current directory, up to four levels down |
| `kit workspace` | exits 2, because it needs a repository |

`kit workspaces --current` says which workspace kit starts on, and why. With `--json`, it also gives what the
workspace menu of kittui draws:

- the members of a group, with their checkouts
- the groups that a repository belongs to
- every group in the file
- the favorites
- the recent repositories whose working trees are still there

#### The last group used

`kit workspaces --use=<name>` keeps the last group used in `${XDG_CACHE_HOME:-~/.cache}/kit/workspaces/last`. This
file is kit's own to rewrite, apart from your file.

- A last group that the file does not hold counts as none.
- `kit workspaces --delete` of the last group used forgets it. A group that you make later under the same name is not
  the last used.

#### Recent repositories

`kit workspaces --use=<folder>` keeps a repository among the recent repositories. Write the folder as a path, such as
`.`, `~/Code/edge`, or `/srv/edge`. kit keeps the repository whose working tree holds the folder, in
`${XDG_CACHE_HOME:-~/.cache}/kit/workspaces/recent`.

- The list holds ten repositories, each once, the newest first.
- A path inside a linked worktree is kept as the desk of its repository, and an earlier entry for that desk moves up.
- A recent repository is not a group. kit starts on it only when you are inside it.
- The workspace menu offers the recent repositories, and its Open Repository… keeps the one it opens.

`kit --workspace=<path> workspaces --current`, with an absolute path, names the repository whose working tree holds
the path. It exits 2 where no repository does.

### Which verbs take --workspace=

`--workspace=` is an option of `kit` itself. The loader, `kit/bin/kit`, reads it and hands it to the verb. A verb
refuses `--workspace` among its own words.

| Verbs | What `--workspace=` does |
| --- | --- |
| `kit flow`, `kit workspace`, `kit issues`, `kit changes`, `kit delivery`, `kit people`, `kit trust`, `kit platform`, `kit packages` | runs the verb in every cloned member's checkout |
| `kit welcome` | checks the folders of the workspace |
| `kit workspaces --current` | names the workspace |
| `kit tui <verb>` and a verb typed short of its arguments | opens the verb's form over the workspace |
| every other verb | ignores the option and runs in the folder's repository, or refuses outside one |

- A call across a workspace runs on the kit that you installed. The call for each member runs the release that the
  member pins. So `--workspace=` takes no `--version=`.
- Over a workspace, `kit flow` draws kit's five stages, whatever the `flow` setting in the `kit.yml` where you run it
  says. `--stages`, `--marks`, and `--quota` span the members too. A pull request's number and `--me` name one
  repository's, so kit refuses them.
- Each row says where it comes from: `organization`, `repository`, and `source`, and each row gains `member`. A member
  that kit could not read is `{member, error}` under `errors`, and the others still print. A member whose document
  states another contract is under `errors` too, and kit does not merge it. See
  [apps.md](apps.md#the-contract-of-the-stage-documents).
- `kit flow` exits 1 when it cannot read a member. With `--json`, it still prints what it read. `--marks` names such a
  member under `errors`, beside the marks, and `--quota` leaves its rate limits out. Both print the member's line on
  stderr.
- A member with no checkout draws no stage. `kit workspace repos` lists it.

### The options of kit workspaces

| Form | What it does |
| --- | --- |
| `kit workspaces` | lists the groups and the favorites |
| `--show=<workspace>` | shows a group's members, or a repository |
| `--current` | says which workspace kit starts on here, and why |
| `--use=<workspace>`, `--use=<folder>` | remembers the last group used, or a recent repository |
| `--new=<name>` | makes a group |
| `--add=<name>`, `--remove=<name>` | adds repositories to a group, or takes them out |
| `--rename=<name> <new-name>` | renames a group |
| `--delete=<name>` | deletes a group and its favorite |
| `--favorite=<workspace>`, `--unfavorite=<workspace>` | adds a workspace to the favorites, or takes it out |
| `--from=<command>` | with `--new` or `--add`: runs the command, and each line it prints is a repository |

`--new`, `--add`, and `--remove` take a member, a git URL, a checkout's directory, or a pattern.

A pattern matches against one list:

| Form | The pattern matches |
| --- | --- |
| with `--from` | the repositories that the command printed |
| `--remove`, without `--from` | the members of the group |
| `--new` and `--add`, without `--from` | the members of the checkouts under your roots |

- A pattern that matches nothing is a usage error, and kit exits 2.
- With no pattern, every repository that the `--from` command printed joins the group.
- Each form that edits the file, and `--use`, takes the file's lock first. So two commands that edit the file at the
  same time each land. kit waits up to 30 seconds for a lock that another live process holds.

`kit workspaces` exits:

| Status | When |
| --- | --- |
| 0 | it printed or edited |
| 1 | it cannot read or edit the file, because another command holds its lock past the wait, or because `${XDG_CACHE_HOME:-~/.cache}/kit/workspaces/` cannot be written |
| 2 | a usage error, an unknown workspace, or a new name that is refused or taken |

## kittui and workspaces

Three screens work with workspaces: the workspace menu, the Open Repository… dialog with its Find clones table, and
the workspaces screen.

### The workspace menu

The workspace menu is the `-` on every screen's title line. Click it, or press `-`, to drop down the workspaces that
you can switch to. The menu lists, in this order:

1. the groups that the repository here belongs to
2. your favorites
3. every other group in the file
4. the recent repositories, with the one shown first, or the one that the worktree shown belongs to, unless a
   favorite already names it
5. Open Repository…
6. Manage…

A line is dim when you cannot switch to it now: the workspace shown, and a favorite repository with no checkout.

| Line | What it does |
| --- | --- |
| a group, a favorite, or a recent repository | switches to it |
| Open Repository… | opens the dialog that opens a repository by its folder |
| Manage… | opens the workspaces screen |

After a switch to another workspace, kittui drops every crumb, because the apps are made anew there.

#### Forms and the workspace

A verb's form runs in the workspace shown.

| After a switch to | The form runs the verb |
| --- | --- |
| a repository | in that repository's checkout |
| a group | in the folder where kittui started, as `kit --workspace=<group> <verb>` |

- The command line that kittui leaves in the scrollback says both the workspace, and a `cd` first when the verb ran
  in another folder than the one where kittui started.
- A form that is open at the switch is closed, because its choices were read in the folder before. The help shows its
  palette there.
- A verb that you type short of its arguments after `kit --workspace=<group>` opens its form over that group.
  `kit --workspace=<group> tui <verb>` does the same.

### Open Repository…

The dialog opens a repository by its folder.

| Control | What it does |
| --- | --- |
| type a folder | `~` is your home folder, and a path with no `/` at its start is read from there |
| paste a path that starts with `/` or `~` | the pasted path replaces what you typed |
| `⇥` | completes the folder, one folder at a time |
| click a folder in the list under the field | goes into that folder |
| Enter, or click Open | opens the folder typed |
| `esc`, or a click off the box | closes the dialog |

A folder that is in no git working tree is refused with one line in the dialog, which stays open.

#### Find clones

Find clones, or `⌃F`, walks the folder typed for git working trees. It shows the clones that it finds as a table, as
kittui shows every list.

- Each repository that it found with its worktrees is a heading over its checkout and its worktrees.
- The repositories found alone are under one heading, with no worktrees, last.
- A 📚 column marks a clone whose repository is a member of the group shown.

| Control | What it does |
| --- | --- |
| click ▸ or ▾ | opens or closes a heading |
| `<`, `>` | closes or opens every heading, one level at a time |
| space, `⇧↑↓`, `⌃A`, click a row's mark | selects clones |
| Add (`+`) | drops down the groups in the file; the group you pick takes the selected clones as members, or every clone found while none is selected |
| Remove (`-`) | takes the selected clones out of the group shown |
| Open (`⏎`) | opens the clone under the cursor |
| `esc` | goes back to the folders |

The three lines under the table are plain clicks, and each is dim while it cannot act. Add and Remove run
`kit workspaces --add=` and `--remove=` with the clones' folders. kit's answer shows in the dialog, which stays open,
and the 📚 column follows the group as it is now.

### The workspaces screen

Manage… opens the workspaces screen. It has one row for each group. A row shows whether the group is a favorite, how
many members it has, and the members.

The app's menu, `=`, holds what you can do to the group under the cursor. Each line is a plain click, and each has a
key that does the same with the menu closed. Each action runs a `kit workspaces` command. kittui never writes the file
itself.

| Action | Key | What it asks for |
| --- | --- | --- |
| New Workspace… | `n` | a name and its repositories |
| Switch to It | `⏎` | nothing |
| Favorite or Unfavorite | `f` | nothing |
| Workspace… | | opens a menu of the actions below; `esc` goes back to the app's menu |
| Rename… | `r` | the new name |
| Add Members… | `a` | repositories and patterns |
| Add an Owner's Repositories… | `o` | a GitHub owner and a pattern; it runs `gh repo list` through `--from` |
| Add from a Command… | `c` | a command that prints one repository on each line |
| Remove Members… | `x` | repositories and patterns |
| Delete… | `d` | a confirmation |

- Every action but New Workspace… acts on the group under the cursor. With no group under the cursor, only New
  Workspace… acts, and the menus show the rest dim.
- When kit refuses, its line shows in the action's dialog.
- When kit is done, every screen's workspace menu lists the groups as they are now. kittui follows a group that you
  renamed or deleted while it is shown.
- The title line of the screen has a crumb: ↩ and the name of the screen that you chose Manage… on. Click it, or
  press `⌫`, to go back.

## Not built yet

The first three steps of [the workspaces design](superpowers/specs/2026-11-08-workspaces-design.md) are built: the
file, `kit workspaces` with fixed members, checkout discovery, the start rule, the workspace menu, and Flow across the
members that have checkouts. The other steps are designed and not built:

- Queries, ☁️ members, batched forge reads, and the query cache. kit refuses a group's `match` by name until then.
- Topics and git config labels as filters.
- GitHub Project workspaces. kit refuses a group's `project` by name until then.
- Browse…, a picker of every checkout under your roots, with groups suggested from owners.
