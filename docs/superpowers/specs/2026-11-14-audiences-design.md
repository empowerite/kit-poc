# Audiences: design

An audience is a kind of reader of software work, as kit shows it: a developer, a platform engineer, a security
engineer, a person who answers for cost, a person who answers for a team's results, or an auditor who checks the work
from outside it. This page describes each audience by the questions it asks of the work, the entities that answer
them, and what "mine" means to it. The entities are the ones in [the entities design](2026-11-09-entities-design.md).

An organization defines its own roles: what each is called, which entities it reads, and which views it starts from. The
audiences here are a starter set kit ships for an organization to take, rename, change, or replace; see
[Roles the organization defines](#roles-the-organization-defines).

## Intent

kit is a proof of concept for a software development life cycle (SDLC) that works the same whatever tools carry it.
A question such as "what is waiting on me?" has the same shape on GitHub, GitLab, Azure DevOps, and Jira. If kit
asks the question of the work and not of the tool, a migration from one tool to another changes a provider and a
mapping, and leaves every view, filter, and habit of the people who read the work as it was. Migrations are where
enterprises lose that continuity, so the proof of concept is built to keep it.

Nobody uses kittui yet. These audiences are the ones the proof of concept is shown to. They come from what each role
does, not from interviews, and the owner is to correct them.

This page is the first of three. The second gives every field one meaning across every tab: `issue.id`, not `id`. The
third lets a person's filters, sorting, and grouping follow them from tab to tab. Both need to know who the readers
are, so this page comes first.

## Goals

- Name each audience, with the questions it asks, worded without any tool's own terms.
- Name the entities each audience reads, and the relation each audience means by "mine".
- Find the dimensions every audience slices by, because a view that follows a person must carry those.
- Find what the entities design lacks for an audience, so the second page can add it.

## Non-goals

- A fixed list of roles, or a fixed set of views per role. An organization defines its roles, and a person's views are
  theirs to save.
- Permissions. What a role may see is the service's own rule, and kit never widens it.
- Research with real users. No user exists yet, and this page says so where it matters.

## Anti-goals

- A question that needs a tool's word to ask. "Which GitHub pull requests are open?" fails; "which changes are waiting
  on a review?" passes. A question that fails is a finding, because the view built on it would not survive a
  migration.
- A role written to look complete. A role whose questions kit cannot answer yet is listed with the gap, never given
  invented questions.
- A role that changes a verdict. A role decides what a person sees, never what kit enforces.
- An audience whose view differs by tool. If the same person asks the same question after a migration, the same view
  answers it.

## Terms

- Audience: a kind of reader of the work, which this page describes. kit ships seven as a starter set.
- Role: an organization's own definition of an audience: its name, the entities it reads, its views, its slices, and
  what "mine" means for it. A person holds one role or several.
- Question: what an audience asks of the work, in words that name no tool.
- Entity: a thing kit names, such as an issue or a deployment; see
  [the entities design](2026-11-09-entities-design.md#terms).
- Stage: one read kit makes, which prints rows of one entity. A tab is kittui's page that draws a stage.
- Relation: how a person stands to an entity. A person is the assignee of an issue, the author of a change, a
  reviewer of a change, the approver of a deployment, or a member of the team that owns a repository.
- Mine: the entities a person stands in some relation to. Which relation counts depends on the entity and on the
  audience.
- Slice: a field a person groups, sorts, or filters by, such as the repository or the environment.

## The audiences

| Audience | What it answers for | Reads mostly |
| --- | --- | --- |
| Developer | the change in front of them and the issue behind it | issues, changes, runs, reviews |
| DevOps | how work reaches production and stays there | pipelines, runs, artifacts, environments, deployments |
| SecOps | whether what runs can be trusted | findings, evidence, controls, waivers, policy |
| FinOps | what the work costs and who it is charged to | runs, artifacts, environments, agents, teams |
| Team lead | one team's flow and health | issues, iterations, changes, reviews, people |
| Executive | many teams' results and risk, in aggregate | milestones, releases, controls, deployments |
| Auditor | whether the work met its obligations, as of a date, for someone outside it | controls, evidence, approvals, waivers, changes |

These seven are a starter set, not a list kit enforces. The sections below list each audience's questions. Each
question is worded to pass the anti-goal above. An entity in italics is one the entities design does not hold yet; see
[What the entities lack](#what-the-entities-lack).

### Developer

Questions:

- What is waiting on me: changes I wrote that a reviewer has answered, and changes I am asked to review?
- What did my last change break, and which run says so?
- Which issue am I on, and what is it blocked by?
- Where is my change now: reviewed, merged, released, deployed?
- What did an agent do for me, and what is left for me to accept?

Reads: issue, change, review, check, run, release, deployment, agent.

Mine: assignee of an issue, author of a change, requested reviewer of a change, the person an agent acts for. All of
them count together, so "mine" on Changes means authored or asked to review.

### DevOps

Questions:

- What version runs in each environment, and do the targets of one environment agree?
- Which runs failed in the last day, and which failure repeats?
- What is queued to deploy, and what is it waiting for?
- Which artifact is in production, and which commit built it?
- Which pipelines have no owner?

Reads: pipeline, run, artifact, environment, deployment, target, fleet, team.

Mine: the actor of a run or a deployment, and the owner of a repository, pipeline, or environment. Ownership comes
from a team, so "mine" here reads through the team the person is on.

### SecOps

Questions:

- Which findings are open, by severity, and which are past the time to fix them?
- Which production changes lack review by someone other than their author?
- Which waivers expire this month, and who granted them?
- Does every artifact running in production have evidence, and of what kind?
- Which dependencies carry a known weakness, and where do they run?

Reads: finding, evidence, control, waiver, policy, approval, artifact, deployment.

Mine: the owner of a finding's repository, the grantor or subject of a waiver, and the approver of a change. SecOps
more often reads everyone's, so the filter they carry is usually a severity or a control, not themselves.

### FinOps

Questions:

- What did runs cost this month, by team and by repository?
- Which environments run and are used by no one?
- Which artifacts and stored evidence cost the most to keep, and which are past their retention?
- What did agents spend, per person and per issue?
- Which team's spend is growing faster than its output?

Reads: run, artifact, artifact store, environment, agent, team, *cost*, *budget*.

Mine: the team a person is on, and the people on that team. A FinOps reader seldom means themselves.

This is the audience the entities design serves least. It names no cost, no budget, and no usage, and it has no way to
charge anything to a team. The gap is the largest in this page.

### Team lead

Questions:

- What is this iteration's scope, and how much is done?
- Who is overloaded, and who is blocked?
- Which changes have waited longest for review?
- What is my team shipping that other teams wait on?
- Which of my team's issues have no owner?

Reads: issue, iteration, change, review, person, team.

Mine: my team's, not mine. The relation is membership in a team, then any relation one of the members holds. "Mine"
and "my team's" are different filters, and a team lead moves between them.

### Executive

Questions:

- Which releases are on track for their date?
- Which controls are met, and which are at risk?
- Where is the same work done twice, across teams?
- What reached production this quarter, and what did it cost?
- Which risks are accepted, by whom, and until when?

Reads: milestone, release, control, waiver, deployment, *cost*.

Mine: the organization or the group of teams a person answers for. An executive reads aggregates, counts and rates
and not rows, so a view for them stands for a tab that totals; see
[Open questions](#open-questions).

### Auditor

An auditor may be internal, in a risk or compliance group, or external, a firm that certifies the organization against
a standard. They differ from SecOps in three ways. They act on no one's behalf in the work, so what they read must hold
without trusting the people who did it. They read as of a date, not as of now. And they test a population and a sample
of it, not the open items.

Questions:

- Which controls applied between two dates, and which are met, from evidence that no desk could have made?
- Of every production change in the period, how many had a review by someone other than the author, and which did not?
- Which sample of changes shows the whole chain: issue, review, checks, approval, deployment?
- Which waivers were in force on a given date, who granted them, and had they expired?
- What did the policy say on the date of this change, and which version applied?
- Is the evidence still held for the retention period, and does its signature verify?

Reads: control, evidence, evidence store, approval, waiver, policy, change, review, deployment, and the chain between
them.

Mine: none. An auditor's subject is a scope, a control or a period or a system, and not themselves. They carry the
scope from tab to tab, so it is the one audience whose carried filter is never a relation to a person.

An auditor needs three things no other audience needs: a date every view can be read as of, a population that can be
counted and sampled, and a view that can be handed over whole. The entities design keeps evidence outside the platform
that made it, which serves an auditor's need for independence. It holds no history, no sample, and no export; see
[What the entities lack](#what-the-entities-lack).

## Roles the organization defines

An organization decides which roles it has, what each is called, and what each cares about. kit has no built-in role. A
role holds:

| Part | Holds |
| --- | --- |
| name | what the organization calls it, in its own words: "Platform Engineer", "Controller", "Release Captain" |
| reads | the entities the role looks at, named as kit names them, in the order the role wants them |
| views | the views the role starts from, one for each question it asks, kept as shared presets |
| slices | the fields the role groups, sorts, and filters by, which a view carries from tab to tab |
| mine | the relations "mine" means for the role: assignee, author, reviewer, owner, or none |

How a role works:

- The name is the organization's. The entities and fields a role points at keep kit's names, because one name for each
  entity is a goal of the entities design, and a view that follows a person needs the same name on every tab.
- A role lives where the entities design puts a value an organization owns: in a source package for all repositories,
  or for a selection of them. See [Configuration](2026-11-09-entities-design.md#configuration).
- A role is a preference, not a setting. It decides what a person sees. At the same reach the person wins over the
  organization, so a person may add a view to a role, hide one, or reorder them.
- A person may hold several roles. A team lead who also writes code holds two, and sees the tabs and views of both.
- A role may name an entity or a field a tab lacks. The tab ignores it, as it ignores a preset's setting for a field it
  lacks, and a role never refuses a tab.
- The first release lets a person choose their roles. Later the organization's directory can assign them, through the
  identity capability: the members of a team hold the role the organization maps to that team. See
  [Actors](2026-11-09-entities-design.md#actors).
- The starter set is a package like any other. An organization that takes it gets the seven audiences, and one that
  replaces it gets its own roles and none of ours.

## What every audience slices by

A view that follows a person must carry the slices every audience shares. This table says which slices each audience
reaches for, most often first.

| Audience | Slices |
| --- | --- |
| Developer | repository, iteration, state, the relation to me |
| DevOps | environment, repository, state, time |
| SecOps | severity, control, repository, owner |
| FinOps | team, environment, repository, time |
| Team lead | team, iteration, state, assignee |
| Executive | organization, team, milestone, time |
| Auditor | control, period, as-of date, environment |

Findings from the table:

- Repository, state, and time appear for most audiences, so they carry first.
- Team appears for four audiences. A team is an entity of its own in the entities design, so `team.handle` is one
  field on every tab that shows work.
- Organization and repository nest: a person who groups by organization, then repository, expects both groups on
  every tab that has both fields. This is the case that started this work.
- Time is a window, not a value. A view that carries "the last 7 days" carries a relative window, so a saved view
  does not freeze to a date.
- An auditor's slices are not a person's. A control, a period, and an as-of date describe a scope, so a carried filter
  is either a relation to a person or a scope, and the second page names both.
- State means a different set of values on each entity. A view that carries "open" carries a meaning that must exist
  on every tab it reaches, or the filter does nothing there.

## What the entities lack

Each gap is a candidate for the second page, not a decision.

| Gap | Needed by | Why |
| --- | --- | --- |
| Cost, budget, usage | FinOps, Executive | no entity holds money, minutes, or tokens, and nothing charges them to a team |
| Ownership | DevOps, SecOps, Team lead | a team owns a repository, a pipeline, or an environment, and the design lists no such relation |
| Relation to a person | every audience | "mine" is a different relation on each entity, and the design names none of them |
| Severity, age, time to fix | SecOps | a finding holds none of them as a field |
| Aggregates | Executive | the design describes rows, and an executive reads totals and rates |
| As-of reads | Auditor | the design holds what is true now, and an auditor asks what was true on a date |
| Population and sample | Auditor | an auditor counts every subject in a scope and draws a sample, which no tab does |
| Export | Auditor | an auditor hands a view to someone who has no kit, so it must leave as a document |

## What a migration changes

A migration moves work from one tool to another. For each audience, this is what it should change and what it should
leave alone.

- Changes: the provider that answers, and the mapping from the new tool's fields to the work fields.
- Leaves alone: the question, the entity, the field names, and every saved view and filter a person carries.

A view that breaks in a migration shows a field that has a tool's meaning, not the work's. Such a field is a bug in the
vocabulary, which the second page fixes by naming the field for the work: `issue.iteration`, not a sprint label.

## Approaches

Three ways to record audiences were considered.

1. A fixed set of views per role. kit ships "Developer", "FinOps", and the rest, each a set of saved views. It is easy
   to demonstrate. It builds the role into the product, so a person who is both a developer and a team lead must pick
   one, and a tool's own terms leak into the views.
2. Questions first, with roles as named sets of questions. Every question is a statement about entities and
   relations, and a view answers one. A role is a list, and a person may hold several. It costs more thought before
   it shows anything. Roles are data an organization owns, which this page's approach needs and which the owner asked
   for.
3. No roles: a vocabulary alone, and each person builds their own views. It is the smallest. It gives the proof of
   concept no story about who the work is for.

This page takes the second. The owner approved the order of the three pages, not this choice, so it is my call and open
to change.

## My calls

- The seven audiences. The owner named Dev, DevOps, SecOps, FinOps, and management "at various levels", and later an
  auditor. I split management into a team lead and an executive, and I left out release manager, QA, and support. A
  release manager reads like DevOps here.
- That a role is a preference the organization owns, held in the places the entities design gives such a value, and
  that kit ships the seven audiences as a starter package and holds no role of its own.
- That the entities and fields a role names keep kit's names while the role's own name is free. Otherwise a view could
  not follow a person across tabs.
- The questions. They come from what each role is known to do, and no user confirmed them.
- Naming FinOps as the largest gap, because the entities design has no entity for money.

## Open questions

- Which audiences does the proof of concept's first demonstration show, and which is the migration it shows: from
  which tool to which?
- Is "my team's" part of the first release, or is "mine" enough? It decides whether ownership enters the second page.
- Does a view carry to a tab that totals, such as an executive's, or only to tabs of rows?
- How does a person get a role in the first release, when the directory is not built: their own choice, or a role
  assigned in the workspace's file?
- Does the first release read as of a date, which an auditor needs, or only as of now? It decides whether the second
  page names a time field on every entity.
- Is the AI spend of agents a FinOps question in the first release? The entities design has an agent entity and no
  cost for it.

## What follows

1. The field vocabulary: an `entity.field` name for every field of every tab, the relations that "mine" reads, the
   shape of a role definition, and the gaps above that the owner accepts.
2. Views that follow a person: how filters, sorting, and grouping carry from tab to tab on that vocabulary, and how a
   field a tab lacks is ignored.
