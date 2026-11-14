# Audiences: design

An audience is a role that reads the state of software work through kit: a developer, a platform engineer, a security
engineer, a person who answers for cost, or a person who answers for a team's results. This page describes each
audience by the questions it asks of the work, the entities that answer them, and what "mine" means to it. The
entities are the ones in [the entities design](2026-11-09-entities-design.md).

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

- A fixed set of views per role. A role is a set of questions, and a person's views are theirs to save.
- Permissions. What a role may see is the service's own rule, and kit never widens it.
- Research with real users. No user exists yet, and this page says so where it matters.

## Anti-goals

- A question that needs a tool's word to ask. "Which GitHub pull requests are open?" fails; "which changes are waiting
  on a review?" passes. A question that fails is a finding, because the view built on it would not survive a
  migration.
- A role written to look complete. A role whose questions kit cannot answer yet is listed with the gap, never given
  invented questions.
- An audience whose view differs by tool. If the same person asks the same question after a migration, the same view
  answers it.

## Terms

- Audience: a role that reads the work through kit.
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

The sections below list each audience's questions. Each question is worded to pass the anti-goal above. An entity in
italics is one the entities design does not hold yet; see [What the entities lack](#what-the-entities-lack).

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

Findings from the table:

- Repository, state, and time appear for most audiences, so they carry first.
- Team appears for four audiences. A team is an entity of its own in the entities design, so `team.handle` is one
  field on every tab that shows work.
- Organization and repository nest: a person who groups by organization, then repository, expects both groups on
  every tab that has both fields. This is the case that started this work.
- Time is a window, not a value. A view that carries "the last 7 days" carries a relative window, so a saved view
  does not freeze to a date.
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
   it shows anything.
3. No roles: a vocabulary alone, and each person builds their own views. It is the smallest. It gives the proof of
   concept no story about who the work is for.

This page takes the second. The owner approved the order of the three pages, not this choice, so it is my call and open
to change.

## My calls

- The six audiences. The owner named Dev, DevOps, SecOps, FinOps, and management "at various levels". I split
  management into a team lead and an executive, and I left out release manager, QA, support, and an auditor. A release
  manager reads like DevOps here, and an auditor reads like SecOps.
- The questions. They come from what each role is known to do, and no user confirmed them.
- Naming FinOps as the largest gap, because the entities design has no entity for money.

## Open questions

- Which audiences does the proof of concept's first demonstration show, and which is the migration it shows: from
  which tool to which?
- Is "my team's" part of the first release, or is "mine" enough? It decides whether ownership enters the second page.
- Does a view carry to a tab that totals, such as an executive's, or only to tabs of rows?
- Is the AI spend of agents a FinOps question in the first release? The entities design has an agent entity and no
  cost for it.

## What follows

1. The field vocabulary: an `entity.field` name for every field of every tab, the relations that "mine" reads, and the
   gaps above that the owner accepts.
2. Views that follow a person: how filters, sorting, and grouping carry from tab to tab on that vocabulary, and how a
   field a tab lacks is ignored.
