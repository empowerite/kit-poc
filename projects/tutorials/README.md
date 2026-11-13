# kit tutorials

`projects/tutorials` is the site of kit's tutorials: one web page for each feature, tagged by who it is for. It is a
TypeScript, React, and Vite site, and every page is an MDX file. `kit tutorials` shows the top-level tutorials as
cards, and a card for one of these pages opens it in the browser; the tutorials that ship with kit open in kittui.
Nothing on the site runs a command for the reader.

Each build is for one line of kit, at one base path:

- `/` when `npm run dev` serves it
- `/kit/tutorials/main/` and `/kit/tutorials/<pre-release>/` on this repository's GitHub Pages
- `/kit/tutorials/<major>.<minor>/` on this repository's GitHub Pages, one site for every patch release in the line

## Running it

Node comes from `tools:` in `kit.yml`. In this directory, install the packages once, then serve the site:

```bash
npm ci
npm run dev
```

In a repository with kit, point kit's cards at that server instead of the published site:

```bash
KIT_TUTORIALS_BASE=http://localhost:5173/ kit tutorials
```

`npm run check` runs what the gate, `bin/ci`, runs here: `tsc`, the tests, and a build for the base
`/kit/tutorials/main/`. The build checks what it built and fails, naming the file, on a page that throws, such as one
with a `<Since>` whose version is not `X.Y.Z`; on a page that renders empty; on a route with no `dist/<path>/index.html`;
and on an `href` or `src` in `dist/` that resolves outside the base or names no file. A `TUTORIALS_BASE` that is not a
path, such as a URL, fails it too.

A build reads two variables:

| Variable | Default | What it is |
| --- | --- | --- |
| `TUTORIALS_BASE` | `/` | The base path the site is served at, Vite's `base`, written with its slashes added |
| `TUTORIALS_LINE` | `main` | The line of kit the site is for: `main`, `0.4`, or `0.5.0-rc.1` |

`package.json` denies `fsevents` its install script, through `allowScripts`: the package ships its macOS binary
built, and only the file watchers of Vite and Rollup load it.

## Publishing

The tutorials workflow, `.github/workflows/tutorials.yml`, publishes the site, and nothing else does:
`bin/tutorials publish` refuses to run anywhere but on the CI runner. GitHub Pages serves this repository's `gh-pages`
branch, and each copy of the site is one directory of that branch:

| Push | Directory | Address |
| --- | --- | --- |
| to `main` | `tutorials/main/` | `https://empowerite.github.io/kit/tutorials/main/` |
| of the tag `release/X.Y.Z` | `tutorials/X.Y/` | `https://empowerite.github.io/kit/tutorials/X.Y/` |
| of the tag `release/X.Y.Z-<suffix>` | `tutorials/X.Y.Z-<suffix>/` | `https://empowerite.github.io/kit/tutorials/X.Y.Z-<suffix>/` |

The workflow has two jobs:

1. `build` asks `bin/tutorials site` which copy the ref is, and builds it with `TUTORIALS_BASE` and `TUTORIALS_LINE`
   set from the answer. The address comes from `kit/modules/bash/tutorials.sh`, where kit reads it too, so the copy a
   ref builds is the one that ref's kit opens. The build runs npm's packages, so the job's token only reads.
2. `publish` is handed `dist/`, and runs `bin/tutorials publish`, which replaces the copy's directory in one commit
   and pushes it. Every other copy stays as it is. The copy for `main` also gives the branch its `404.html`. A push
   that is refused, as when another copy landed first, is tried again on the branch as it then stands. Then
   `bin/tutorials answers` asks the copy's address until it answers, for five minutes at most. A copy that Pages
   does not serve fails the run, so a release whose tutorials are a dead link is never a green run.

A pre-release's copy goes with its tag. When a branch is deleted, the retire workflow deletes the pre-releases that
were made from it, and `bin/tutorials retire` then removes the copy of each pre-release whose tag is gone.
`bin/tutorials retire --dry-run` says what it would remove, and changes nothing.

Pages is turned on once, by an owner of the repository. Until then the branch holds the copies, no address
answers, and each run fails at its last step, `answers`:

1. Push a branch that holds the workflow, then start its first run: merge to `main`, or tag a pre-release with
   `kit release`. When the run ends, `git ls-remote origin gh-pages` shows the branch.
2. Turn Pages on. In the repository's settings, under Pages, choose "Deploy from a branch", the branch `gh-pages`,
   and the folder `/ (root)`. From a terminal, this does the same:

   ```bash
   gh api --method POST repos/empowerite/kit/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'
   ```

3. Check that the site answers, with the address of a copy that is published. This asks until the address answers,
   and writes nothing:

   ```bash
   bin/tutorials answers https://empowerite.github.io/kit/tutorials/main/
   ```

   Then run the failed run again, `gh run rerun <run> --failed`, and `kit tutorials --text` prints links that open.

## Content

Every MDX file under `src/content/` is a page, served at a path relative to the base:

| File | Served at | Kind |
| --- | --- | --- |
| `src/content/<id>/index.mdx` | `<id>/` | A top-level tutorial, when its front matter says `top: true` |
| `src/content/<id>/<page>.mdx` | `<id>/<page>/` | A deeper page that a tutorial links to |

Two more pages are in each site's top navigation:

- `src/whats-new.mdx`, served at `whats-new/`: the story of the line's minor release, with links to the tutorials it
  added or changed.
- `src/changelog/<version>.mdx`, one entry for each release, written by hand as part of cutting it. `changelog/`
  shows every entry, newest first.

Each page is pre-rendered to `dist/<path>/index.html`, so a deep link works on any host with no rewrites. A link
between pages is written from the page it is on, as on the web: `[marks](marks/)` on `kit-tutorials/` and
`[the changelog](../changelog/)` on any page one level down, never with a leading `/`. The link keeps the reader's
`?kit=` on the next page. An address that is no page shows "No such page", and the build writes the same page as
`dist/404.html`, which Pages serves for any address with no file.

## Front matter

Every page opens with YAML front matter between two `---` lines. [frontmatter.schema.json](frontmatter.schema.json)
holds it to these keys, and the gate checks every page against it:

| Key | Type | Required | What it is |
| --- | --- | --- | --- |
| `title` | string | always | The page's heading and title |
| `top` | boolean | no, `false` | `true` for a top-level tutorial, one kit lists |
| `summary` | string | when `top` | The sentence on the tutorial's card |
| `glyph` | string | when `top` | The emoji on the tutorial's card |
| `audience` | list of strings | when `top` | Who it is for, at least one id from `audiences.yml` |
| `order` | integer | no, `1000` | Where it stands among the tutorials, lowest first |

[audiences.yml](audiences.yml) is the closed list of audiences, each an `id`, the `label` kit shows, and the `color`
kittui draws its pill on, as `#rrggbb`, dark enough for white text, in the order kit shows them. Adding an audience is
an edit there; `bin/tutorials catalogue` refuses one without a color shaped `#rrggbb`.

## Marking what a patch release added

A passage that a patch release made true is wrapped in `<Since>`, which a page needs no import for:

```mdx
<Since version="0.4.9">
`kit flow` takes `--quota`.
</Since>
```

kit opens every page with its own version in the address, as `?kit=0.4.7`. A passage newer than the reader's kit
says so, "Needs kit 0.4.9; you have 0.4.7.", and how to upgrade: install that version or later, then run `kit
--version=<version> update`, with that version. A pre-release of the passage's own version, `0.4.9-rc.1`, has the
passage. Without `?kit=`, or with `unreleased` or anything that is not a version, the passage is marked plainly,
"Since 0.4.9".
