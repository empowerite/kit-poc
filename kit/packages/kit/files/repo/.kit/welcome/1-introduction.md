<!-- kit:generated -- kit welcome's first step, the introduction, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Introduction — what kit is, where it works, and who it is for

kit is one set of commands for the whole development cycle, the same for people and for coding agents: start work
from an issue, commit, open and update a [pull request](kittui:welcome/terms/pull%20request), run
[CI](kittui:welcome/terms/CI), and make a release.

## One set of commands across your tools

- Coding agents: Claude Code, Cursor, GitHub Copilot, and Gemini CLI each read the same rules, in `.kit/`. The
  rules are not copied into each agent's own files, so there is nothing to regenerate or keep in sync.
- [Code forges](kittui:welcome/terms/code%20forge): GitHub is supported. GitLab and Azure DevOps are experimental:
  the code kit has for each is tested against a fake built from the tool's documented output, and has not yet run
  against a live project. The commands are the same on each.
- [Trackers](kittui:welcome/terms/tracker): the forge's own issues and Azure DevOps work items. One repository can
  use more than one. kit only opens the pages of another tracker, such as Jira or Linear: it reads no issue there,
  so `kit work` starts none and `kit linked` counts none.
- [CI](kittui:welcome/terms/CI): `kit ci` runs the same checks on your machine and in any CI system.
- Repositories: kit shows and acts on a group of repositories as one [workspace](kittui:welcome/terms/workspace).

## Any repository, or installed in one

kit works in any repository as it is. Install it in a repository to do more there: kit adds the rules that every
person and agent follows, checks the work against them on each pull request, and updates them with each kit release.

## Who it is for

- People who work with coding agents and want an agent's work held to the same standard as their own.
- Teams that want the same rules and the same commands in every repository.
- [Agents](kittui:welcome/terms/agent): kit tells an agent where the rules are, which command does each step, and why
  a check failed.
