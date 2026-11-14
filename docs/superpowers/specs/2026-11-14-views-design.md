# Views: presets as scoped mixins

A view is what a tab shows of its datasource: which fields are columns, which are groups, how the rows sort, which rows
are let through, and how each field is drawn. A preset is a named set of those instructions. This page describes how
presets stack, so a person's grouping, sorting, and filtering follow them from tab to tab, and each tab says what it
applies. The readers it serves are in [the audiences design](2026-11-14-audiences-design.md), and the entities its
fields name are in [the entities design](2026-11-09-entities-design.md).

## Intent

A preset belongs to one tab today. A person who groups by organization and then repository, or who filters to what is
theirs, does it again on each tab, because no preset reaches across tabs. The constant customization is annoying
because it cuts across the person's use cases, which span tabs, instead of following them.

The tables already do the hard part: a table groups, sorts, filters, and draws any datasource a tab gives it. What is
missing is the rule for combining what a person wants everywhere with what one app or one tab needs, and a way for
every tab to say what it applied.

## Goals

- A person defines a preset once and it applies wherever it can.
- A narrower scope overrides a broader one, per field and per facet, and can switch a broader constraint off.
- Applying a preset never fails. A constraint a tab cannot use is shown as not applicable, never dropped in silence.
- Every tab shows which presets are in force, at which scope, and which layer decided each constraint.
- An edit stays local until the person saves it, and saving names the preset and picks its scope.
- Presets that exist today keep working, as presets of one tab.

## Non-goals

- A pivot table. The tables have the row axis, the outline, and the filters. A column axis, and measures beyond counts,
  come later, and nothing here prevents them.
- Presets by repository or by workspace. That is a separate axis, which repositories a value reaches, and it is
  orthogonal to where in kittui a preset applies.
- Editing a built-in preset. Built-ins ship with a release and stay as they are.
- Teams, and as-of reads. See [Scope of the first release](2026-11-14-audiences-design.md#scope-of-the-first-release).

## Anti-goals

- A silent ignore of a filter. A filter that does not apply, and shows rows as though it did, misleads, so the tab says
  so.
- A preset that means different things on different tabs. A preset names fields by their meaning, so it means the same
  where it applies.
- A person unable to see why a column is hidden or a row is missing.
- A second table. Views change what the existing table is told, never how it draws.

## Terms

- Datasource: the rows a tab shows, of one primary entity, with the fields of the entities reachable from it. A
  datasource may be shallow, with the entity's own fields, or deep, with fields joined from related entities.
- Field: one named value of a row. Its identity is its meaning, `entity.field`, as the vocabulary page will fix; the
  catalogs' field ids stand until it does.
- Facet: one kind of instruction a preset gives about a field. There are five.
- Preset: a named set of instructions, field by field, each in a facet.
- Scope: where in kittui a preset applies: global, an app, or a tab. This page says scope for that place, because the
  entities design says reach for which repositories a value covers.
- Layer: a preset at a scope, in the stack of one tab.
- Stack: the layers in force on a tab, from the broadest scope to the narrowest, then the edits not yet saved.
- Resolution: the rule that turns a stack into the one preset a tab applies. It is not the outline's fold, which opens
  and closes groups.
- Constraint: one instruction of a layer about one field in one facet.
- Provenance: which layer decided a constraint, and why one that did not decide stands as it does.
- App and tab: an app is one of kittui's apps. A tab is one of an app's pages, and draws one stage, a read kit makes.

## Principles

1. A view is a datasource crossed with presets. The tab supplies the datasource. The person's presets supply the
   instructions. The result is a view.
2. A preset says what a field means, never how a datasource reaches it. Joins belong to the datasource: a join to one
   related row, as an issue's repository, adds fields and keeps the rows; a join to many, as a change's reviewers,
   multiplies rows, which is what a flat field does today. A row without a related row has no value for those fields,
   and is never dropped. A field reached by two relations is told apart by its path: `change.author` and
   `change.reviewer`.
3. Applying never fails, and ignoring is never silent. A field the tab lacks, or cannot sort, group, or filter, makes
   its constraint not applicable. The tab shows it dim, with its reason.
4. The narrowest layer wins, per field and per facet. A list facet, the groups, the sort keys, or the column order,
   is replaced as a whole by a narrower layer that gives one, unless the layer says it adds. A narrower layer can
   switch a broader constraint off.
5. An edit is local until it is saved. Saving is naming: the person gives a name and a scope, and the name is the
   preset's identity at that scope. Saving under an existing name changes that preset for every tab it reaches.
6. A built-in preset never changes. A person who wants a tab to open on their own preset sets which preset the tab opens
   on, which is a preference and not an edit of the built-in.
7. A selection follows the person. The presets active at global and app scope apply on every tab in their scope. A
   tab's base preset is chosen for that tab alone.
8. The view is always visible. Each tab shows its stack and, for any constraint, the layer that decided it.
9. Time is a field's constraint. An instant, as of a date, and a period, from a date to a date, are two kinds of
   filter on a time field, each absolute or relative. See [the audiences design](2026-11-14-audiences-design.md).
10. A total is a group's heading in the outline. A filter narrows the rows, and the totals follow the rows.

## Facets

A layer instructs each field in five facets.

| Facet | Says | List |
| --- | --- | --- |
| place | whether the field is a column, a group, or hidden | the groups, by depth |
| order | where the field stands among the columns | the columns, by position |
| sort | whether the rows sort by the field, and at what priority | the sort keys, by priority |
| filter | the values the rows must hold one of, or none of | none |
| render | the rendering the field is drawn by, and whether a list field stands once per value | none |

The groups, the columns' order, and the sort keys are lists. The rest are decided field by field.

## The resolution

A tab's stack, from the broadest layer to the narrowest, is:

1. the presets active at global scope, in the order the person activated them;
2. the presets active at the tab's app, in order;
3. the tab's base preset, then the presets active at the tab, in order;
4. the edits not yet saved.

The resolution starts from nothing and applies each layer in turn, so a later layer is the narrower.

- A per-field facet, the filter and the render, is set by the layer that gives it. A later layer that gives the same
  field the same facet replaces it. Different fields never interact, so two filters on different fields both hold.
- A list facet, when the layer gives any of its entries, replaces the list, unless the layer lists the facet under
  `add`, which appends the layer's entries after the list so far, the fields already in it left where they are.
- A hidden field stays hidden until a later layer places it as a column or a group. A layer that places a field as a
  column, or gives it a position, takes it out of the groups, and one that hides it takes it out of the groups and the
  order.
- A layer's way to draw a field, its rendering and whether it stands once per value, replaces the broader layers' way as
  a whole.
- A layer switches a constraint off by naming the field and the facet under `off`. The constraint stays off for every
  narrower layer, until one gives it again.
- A field a datasource lacks, and a facet the field cannot take, a sort on a field that cannot sort, are not applied.
  The layer that gave them keeps them, and the resolution reports each as not applicable.

The resolution gives the one preset the tab applies, in the form presets already have, so the table's existing
application of a preset is unchanged. It also gives the provenance: for each constraint of each field, the layer that
decided it, the layers it overrode, and, for a constraint that is not in force, whether it was switched off,
overridden, or not applicable, and why.

A built-in preset states only what differs from the catalog, so a built-in that says nothing about grouping leaves a
global grouping alone. A built-in that groups by member replaces a global grouping on its tab, because its scope is the
narrower.

## What a person sees

The preset line already names the view and holds the presets' menu, and chips say what the filters hold back. The
stack extends it: one chip for each layer in force, each with its scope.

```text
Issues   Underway  ·  Mine (everywhere)  ·  By org, repo (Issues)                📇 Fields  ▼ Presets
```

- A constraint the tab cannot use is dim, with its reason shown on the plain click that opens the chip: "no author on
  this tab". A constraint switched off here is dim and says "off here".
- The name of the base preset is crossed out as soon as the person edits, as it is today: the view is new until it is
  saved. Saving gives the name and the scope, and saving under an existing name changes every tab that name reaches.
- Clicking a constraint opens its card, which says its layer and offers "off here", "off in this app", and "off
  everywhere", and the same for turning it on again.
- The presets' menu lists the presets that apply to this tab, by section: active here, available, and built in. A preset
  whose fields this tab has none of is listed dim, because the tab cannot use it.
- Every action is a plain click, as the rest of kittui is.

## Storage

The person's presets stay in the presets file under the kit's config directory. Each preset gains a scope, and the file
gains the active presets for each scope.

- A preset in a tab's list, as today, has the tab's scope, so files written before this change keep their meaning.
- Presets of global and app scope are listed under their own keys, and each scope keeps its active names in order.
- A file that holds no global or app presets and no active names is written as it is today, so a kittui that does not
  know scopes reads it. A file that holds them is a new version, and an older kittui refuses it, and names the version.
- A global name may not be a built-in's name on any tab, so "Default" is never a person's.
- Saving merges with the file as it is, as it does today, so another kittui's changes to the same file are kept. The
  merge works by name within a scope.

## Approaches

Three ways to carry a preset across tabs were considered.

1. A preset's name is global, and its settings are ignored where a tab lacks the field. It is the smallest change. A
   person cannot narrow a global preset for one tab, and a filter that does not apply misleads.
2. A stack of presets at scopes, resolved narrowest first. A person defines something once, narrows it where needed, and
   sees what applied. It costs a resolution, a scope on each preset, and a line that shows the stack.
3. The model of a pivot table, with a row axis, a column axis, and measures, and views as saved pivots. It is the most
   general. It decides far more than this change needs, and the tables lack the column axis.

This page takes the second, as the owner's reasoning leads to it: a global preset that follows a person, and a mixin of
smaller scope over it. The third stays open as a later step, since the resolution does not prevent it.

## Decisions

The owner decided:

- Presets are mixins that stack from the broadest scope to the narrowest.
- The scopes are global, app, and tab. A workspace or a repository is a separate concern.
- An edit is local until saved, and saving under the original name changes everything that follows that name.
- A constraint that does not apply is shown struck or dim in the preset, not removed.
- Time has two kinds, an instant and a period.

My calls, open to change:

- A list facet is replaced as a whole by a narrower layer, unless the layer adds.
- Switching a constraint off is a named entry in the layer, for the facet and the field.
- Built-in presets never change, and "opens on" is a preference.
- A not-applicable constraint is dim, and a crossed-out name means an unsaved edit, because one cue should mean one
  thing.
- A global preset's name may not equal any tab's built-in name.
- The resolution lands before the line that shows it, so the model is tested before the screens use it.

## What is left to the builder

- The file's exact keys and the migration from the file as it is now.
- Which stages belong to which app, from the apps' own list.
- The wording of the cards and the dim reasons.
- Where the stack line stands when the control line is narrow.
- The tutorials page for views.

## Open questions

- Does a preset's scope change after it is saved, by moving it from the tab to the app?
- Does a person see presets of scopes that do not reach the tab they are on, in the menu, dim?
- How many mixins a scope may hold active before the stack line needs to wrap?
