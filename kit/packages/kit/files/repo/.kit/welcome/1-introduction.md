<!-- kit:generated -- kit welcome's first step, the introduction, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Introduction — let your agents move fast, and trust what they ship

Coding agents are fast, and they take the same shortcuts people do: they call work done when it is not, skip the
tests, and rewrite other people's branches. kit keeps the speed and takes the doubt out. It writes down the rules,
puts them where every agent reads, holds each pull request to them, and takes the work from an issue to a release in
a few short commands.

## Three ideas to start with

- The rules are written once. `.kit/1st.md` is the file every agent reads first, with a rule for each kind of file
  that has rules. Claude Code, Cursor, GitHub Copilot, and Gemini CLI are each pointed at it, so the rules are not
  copied into each agent's own files, and nothing is left to keep in sync.
- The rules are held where an agent cannot talk its way past them. [CI](kittui:welcome/terms/CI) runs `kit ci` on
  every [pull request](kittui:welcome/terms/pull%20request), and fails it when the work breaks a rule. The same checks
  run on your machine, so a failure shows before it is pushed.
- The path from idea to release is the same everywhere. `kit work` turns an [issue](kittui:welcome/terms/issue) into a
  [worktree](kittui:welcome/terms/worktree), a branch, and a draft pull request. `kit commit` commits work that follows
  the rules. kit reaches GitHub; GitLab and Azure DevOps are experimental. The commands are the same on each.

## See it for yourself

- Type `kit` at a terminal. It opens kittui, the terminal UI you are in now, which shows the work as it stands.
- `kit flow` follows each piece of work from an issue to a release, and `kit workspace` shows what git holds across
  your repositories. kittui has nine apps, one for each part of the work, in the menu under `=`.
- `kit tutorials` teaches the screens, a step at a time.
- Everything kittui shows is what a kit command prints, as JSON. A script or an agent reads the same facts you do.

## A release, not a copy

kit comes as a versioned release, and a repository pins the version it uses. A pull request that bumps the version
updates the rules in every repository the same way, and `kit check` fails the build when someone edits a delivered
file in place. An update leaves your own files alone. kit works in any repository as it is: install it in one to add
the rules there. A [workspace](kittui:welcome/terms/workspace) of repositories is shown as one.

## Who it is for

- People who work with coding agents, and want an agent's work held to the same standard as their own.
- Teams that want the same rules and the same commands in every repository.
- [Agents](kittui:welcome/terms/agent): kit tells an agent where the rules are, which command does each step, and why
  a check failed.

The next steps check this machine, then show how kit is built to be changed, then list its words.
