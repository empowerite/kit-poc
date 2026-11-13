<!-- kit:generated -- kit welcome's fourth step, customize, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Customize — kit is a starting point, built to be changed without forking it

A tool that every repository must accept as it is gets dropped. So kit was designed from the start to be changed
by the repository that uses it, and for that change to survive each new release. Five choices make that work.

## Everything kit adds comes from a package

kit adds nothing by itself. A [package](kittui:welcome/terms/package) is a directory in a release, and every file kit
delivers belongs to one. A repository chooses its packages: the `kit` package for the rules, one style package for each
kind of file whose looks it wants held, and a package for each agent it uses. To stop using something, remove its
package, and kit takes out what the package added.

## Settings live in one file

`kit.yml` is the one file of settings. It lists the active packages, the version of kit the repository pins, the
stages `kit flow` shows, the patterns that names must match, and which remote is the
[primary](kittui:welcome/terms/primary). `kit packages add` and `kit packages remove` change the list of packages, so
nobody edits it by hand.

## Rules are data, with a remedy

A naming rule is a pattern, and each one comes with the remedy a refusal prints. A team changes a pattern in `kit.yml`,
and `kit work` makes names that pass it, while `kit commit` and CI hold every name to it. A rule is a file under
`.kit/`, so a person and an agent read the same words.

## A repository's own package wins

Where a repository wants a delivered file to say something else, it writes a
[house package](kittui:welcome/terms/house%20package): a package of its own under `.kit/packages/<name>/`, in the
same shape as the kit's. It depends on the package that delivers the file, and places its own file at the same path.
The later package wins. The repository never edits a delivered file in place, since `kit check` fails the build when
a delivered file differs from the release.

## An update leaves your files alone

A release is versioned and pinned, and a pull request that bumps the version brings the new rules. Because a change is
a package and not an edit, an update replaces what kit delivered and nothing else. A file that kit shares with the
repository, such as `AGENTS.md`, holds only a region that kit owns, and the rest is the repository's.

## When this matters

Nothing here needs doing now. These choices matter on the day a team wants to change a rule. This guide knows no
repository, so it cannot show yours; inside one, `kit packages` lists the packages in reach and which are active,
`kit policy` shows its naming rules, and `.kit/1st.md` explains "Changing what kit adds". The reference is
[docs/packages.md](https://github.com/empowerite/kit/blob/main/docs/packages.md), and the other docs are at
<https://github.com/empowerite/kit>.
