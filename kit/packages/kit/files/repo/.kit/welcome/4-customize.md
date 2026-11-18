<!-- kit:generated -- kit welcome's fourth step, customize, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Customize — kit is built to be changed without forking it

A tool that every repository must accept as it is gets dropped, and a tool that a repository edits in place cannot be
updated. kit takes a third way: a repository changes what kit gives it by adding to it, so the next release still
arrives. Six choices make that work.

## Everything kit adds comes from a package

kit adds nothing by itself. A [package](kittui:welcome/terms/package) is a directory in a release, and every file kit
delivers belongs to one: the rules, a style for each kind of file, the CI job, the settings for each agent. A
repository takes the packages it wants and drops the rest. Removing a package takes out what it added, and a
[bundle](kittui:welcome/terms/bundle) such as empowerite lets a repository take a set at once, then remove one member.

## What kit delivers cannot be edited, so it can be replaced

A delivered file is a link to its release, or a copy without the write bit, and `kit check` fails when one differs
from the release. So a repository never edits one. It writes a [house package](kittui:welcome/terms/house%20package) of
its own, in the same shape as kit's, that depends on the package it wants to change and places its own file at the
same path. The later package wins. The same way replaces a rule, a style, a template, or a page of this guide.

## A file that is shared has a part that is kit's

Some files belong to the repository and hold a little of kit, such as `AGENTS.md` or `.gitignore`. kit writes only
its own [region](kittui:welcome/terms/region) or its own entries there, and the rest stays the repository's. An update
rewrites the region and nothing else.

## Rules are data, found at run time

kit's four CI checks are fixed, but what each runs is found from the repository. The linter of a
[rule](kittui:welcome/terms/rule), the checks it names, and the templates of a [style](kittui:welcome/terms/style) sit
in the rule's own file. So a repository adds a [kind](kittui:welcome/terms/kind) of file, a rule for it, and a style,
and `kit lint` runs them with the rest. `kit new` makes each one, and a code forge, tracker, or toolchain provider.

## Settings are one file, with defaults a package can set

`kit.yml` holds a repository's choices: the packages, the pinned release, the stages `kit flow` shows, the remote kit
reads issues from, and the answers a template asks for. The
[policy](kittui:welcome/terms/policy), the patterns that branch names, commit subjects, and pull request titles must
match, has defaults from the packages, and `kit.yml` wins over them. A team can also name its own gate, the command
that says its work passes, and its own policy engine.

## An update leaves your files alone

A release is versioned and pinned, and a pull request that bumps the version brings the new rules. Because a change is
a package and not an edit, an update replaces what kit delivered and nothing else, in every repository the same way.

## When this matters

Nothing here needs doing now. These choices matter on the day a team wants a rule to say something else. This guide
knows no repository, so it cannot show yours. In one, `kit packages` lists the packages in reach and which are active,
`kit policy` shows its rules, and `.kit/1st.md` has a section, "Changing what kit adds", with the steps. The reference
is at <https://github.com/empowerite/kit/blob/main/docs/packages.md>.
