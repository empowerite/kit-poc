<!-- kit:generated -- kit welcome's first step, the introduction, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Introduction — let your agents move fast, and trust what they ship

Coding agents are fast, and they take the same shortcuts people do: they call work done when it is not, skip the
tests, and rewrite other people's branches. kit keeps the speed and takes the doubt out. Type `kit work 7` and a
[worktree](kittui:welcome/terms/worktree), a branch, and a draft [pull request](kittui:welcome/terms/pull%20request)
for [issue](kittui:welcome/terms/issue) 7 exist in seconds. The agent works there, under rules it cannot talk its
way past, and a person merges what passes. Four ideas make that work.

## Commands: each step of the work is one command

- `kit work` starts an issue. `kit commit` runs the linters over what is staged and holds the subject to the
  [policy](kittui:welcome/terms/policy) before the commit exists. `kit submit` pushes, `kit rebase` brings the branch
  up to date, `kit ready` asks for review, and `kit tidy` clears away what was merged.
- Each command refuses what would go wrong: a commit at the [desk](kittui:welcome/terms/desk) or on the default
  branch, a push that would overwrite someone's work, a name that breaks the policy. The refusal names the command
  that does the job right.
- Every command prints what it knows as JSON as well, so a script reads the same facts you do. `kit help <verb>` says
  what each one takes, refuses, and exits with.

## Rules: written once, held everywhere

- A [rule](kittui:welcome/terms/rule) says what work on one [kind](kittui:welcome/terms/kind) of file must do to be
  trusted, and names the [linter](kittui:welcome/terms/linter) that checks it. A [style](kittui:welcome/terms/style)
  says how the file looks. `kit context <path>` prints the ones that govern a file, so an agent reads what applies.
- In a repository that uses kit, `.kit/1st.md` is the file every agent reads first. The rules are written there once,
  and each agent is pointed at that file, so nothing is copied into five places and kept in sync.
- [CI](kittui:welcome/terms/CI) runs `kit ci` on every pull request: the repository's own gate, `kit check`,
  `kit linked`, and `kit policy`. The same checks run on your machine, so a failure shows before the push.

## Workspace: one view over every repository

- A [workspace](kittui:welcome/terms/workspace) is one repository or a group of them that you name. `kit flow` follows
  each piece of work in it from an issue to a pull request, a build, and a release, and `kit workspace` shows what git
  holds across the group.
- Type `kit` at a terminal. It opens kittui, the screen you are in now. It has nine apps, one for each part of the
  work, in the menu under `=`, and `kit tutorials` teaches them a step at a time.

## Agents: held to the same standard as you

- An [agent](kittui:welcome/terms/agent) works in a worktree of its own, never at the desk, and never merges: a person
  does, after review. Claude Code, Cursor, GitHub Copilot, and Gemini CLI each have a package that points them at
  `.kit/1st.md`, and `kit serve` offers the rules and some commands to an agent over MCP.
- Where kit can enforce a rule, it does. The packages for Claude Code and Gemini CLI carry a deny list that refuses
  the raw git commands the kit commands replace. It matches literal patterns, so it is not a lock, and the other
  agents get advice alone. `kit trust enforcement` shows which is which in a repository.

## Where it works

- [Code forges](kittui:welcome/terms/code%20forge): GitHub is supported. GitLab and Azure DevOps are experimental:
  the code kit has for each is tested against a fake built from the tool's documented output, and has not yet run
  against a live project. The commands are the same on each.
- [Trackers](kittui:welcome/terms/tracker): the forge's own issues and Azure DevOps work items. One repository can
  use more than one. kit only opens the pages of another tracker, such as Jira or Linear: it reads no issue there,
  so `kit work` starts none and `kit linked` counts none.
- kit comes as a versioned release, and a repository pins the version it uses. A pull request that bumps the version
  updates the rules in every repository the same way, and `kit check` fails when someone edits a delivered file in
  place.
