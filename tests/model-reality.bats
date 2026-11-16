#!/usr/bin/env bats
# model-reality.bats - the model held to reality: what git stores in a fixture repository, and what kit prints of it
# ----------------------------------------------------------------------------------------------------------------------
# setup_file builds one world for the file: tests/fixtures/model-repo/build makes a repository with every case the
# model names, a fake gh answers for its GitHub origin, and a workspace file names it. Then setup_file runs, in it,
# every verb a held field's read-by names and every verb whose rows the Code entities stand for, and keeps what each
# prints, so no test runs a verb over the repository and no two tests write to it. The model is read as kit model
# reads it, model:load then model::build, from the release's modules/model or from a copy.
#
# Each test is a check over the model, and fails naming what it found:
#
#   - git's side: every header, part, and tree mode of every object; every config key; every ref, file of a git
#     directory, and worktree state; and every stage, flag, and extension of an index. A table in this file maps each
#     to the members of the model that hold it, as Entity.member or Entity.field=value for an enum's value. What git
#     wrote that the table does not map fails, and so does an entry whose member the model does not hold. Each walk
#     first asserts its reach, the cases the fixture is built to hold, so a walk that observed nothing never passes,
#     and a git call that fails or writes an error ends the walk, naming the call.
#   - kit's side: every held field's read-by is printed by its verb, not only as null; every read-by names a verb and
#     words kit takes; and every top-level key a row of a Code verb prints is named by a read-by of that verb, or is on
#     the allowlist with its reason.
#
# Beside each check, a test feeds it a copy of the model with one member taken out or one read-by broken, and expects
# it to name what is missing.

bats_require_minimum_version 1.5.0

load helper

world=${BATS_FILE_TMPDIR}/world/model/root

# What git writes, and the members of the model that hold it. A header git does not know is held by extra-headers;
# x-model-extra is the one the fixture writes.
object_names='{
  "object type": {"blob": ["GitObject.Blob"], "tree": ["GitObject.Tree"], "commit": ["GitObject.Commit"],
                  "tag": ["GitObject.Tag"]},
  "commit header": {"tree": ["GitCommit.tree"], "parent": ["GitCommit.parents"], "author": ["GitCommit.author"],
                    "committer": ["GitCommit.committer"], "encoding": ["GitCommit.encoding"],
                    "gpgsig": ["GitCommit.signature"], "gpgsig-sha256": ["GitCommit.compat-signature"],
                    "mergetag": ["GitCommit.mergetags"], "x-model-extra": ["GitCommit.extra-headers"]},
  "commit part": {"message": ["GitCommit.message", "GitMessage.subject"],
                  "trailers": ["GitMessage.trailers", "GitTrailer.token", "GitTrailer.value"]},
  "tag header": {"object": ["GitTag.target"], "type": ["GitTag.type"], "tag": ["GitTag.name"],
                 "tagger": ["GitTag.tagger"], "gpgsig": ["GitTag.compat-signature"],
                 "gpgsig-sha256": ["GitTag.compat-signature"]},
  "tag type": {"blob": ["GitTag.type=blob"], "tree": ["GitTag.type=tree"], "commit": ["GitTag.type=commit"],
               "tag": ["GitTag.type=tag"]},
  "tag part": {"message": ["GitTag.message", "GitMessage.subject"], "signature": ["GitTag.signature"]},
  "signature armor": {"SSH SIGNATURE": ["GitObjectSignature.format=ssh"],
                      "PGP SIGNATURE": ["GitObjectSignature.format=openpgp"],
                      "SIGNED MESSAGE": ["GitObjectSignature.format=x509"]},
  "signature status": {"G": ["GitObjectSignature.status=G"], "B": ["GitObjectSignature.status=B"],
                       "U": ["GitObjectSignature.status=U"], "X": ["GitObjectSignature.status=X"],
                       "Y": ["GitObjectSignature.status=Y"], "R": ["GitObjectSignature.status=R"],
                       "E": ["GitObjectSignature.status=E"]},
  "tree entry mode": {"100644": ["GitTreeEntry.mode=100644", "GitTreeTarget.Blob"],
                      "100755": ["GitTreeEntry.mode=100755", "GitTreeTarget.Blob"],
                      "100664": ["GitTreeEntry.mode=100664", "GitTreeTarget.Blob"],
                      "120000": ["GitTreeEntry.mode=120000", "GitTreeTarget.Symlink"],
                      "40000": ["GitTreeEntry.mode=40000", "GitTreeTarget.Tree"],
                      "160000": ["GitTreeEntry.mode=160000", "GitTreeTarget.Gitlink"]}
}'

# A config key as git prints it, the section and the name in lower case, with the subsection of a remote, a branch,
# or a submodule written *.
config_names='{
  "config key": {
    "core.repositoryformatversion": ["GitDir.format-version"], "core.bare": ["GitDir.bare"],
    "core.filemode": ["GitDir.file-mode"], "core.logallrefupdates": ["GitDir.log-all-ref-updates"],
    "core.ignorecase": ["GitDir.ignore-case"], "core.precomposeunicode": ["GitDir.precompose-unicode"],
    "core.worktree": ["GitDir.worktree"], "extensions.worktreeconfig": ["GitDir.worktree-config"],
    "extensions.objectformat": ["GitDir.object-format"], "extensions.refstorage": ["GitDir.ref-format"],
    "remote.*.url": ["GitRemoteConfig.urls"], "remote.*.pushurl": ["GitRemoteConfig.push-urls"],
    "remote.*.fetch": ["GitRemoteConfig.fetch"], "remote.*.push": ["GitRemoteConfig.push"],
    "branch.*.remote": ["GitBranchConfig.remote"], "branch.*.merge": ["GitBranchConfig.merge"],
    "branch.*.pushremote": ["GitBranchConfig.push-remote"],
    "user.name": ["GitUserConfig.name"], "user.email": ["GitUserConfig.email"],
    "user.signingkey": ["GitUserConfig.signing-key"], "gpg.format": ["GitUserConfig.gpg-format"],
    "gpg.ssh.allowedsignersfile": ["GitUserConfig.ssh-allowed-signers-file"],
    "commit.gpgsign": ["GitUserConfig.commit-gpg-sign"],
    "submodule.*.url": ["GitSubmodule.configured-url"], "submodule.*.active": ["GitSubmodule.active"]},
  "gitmodules key": {"submodule.*.path": ["GitSubmodule.path"], "submodule.*.url": ["GitSubmodule.url"]},
  "config scope": {"local": ["GitConfigEntry.scope=local"], "worktree": ["GitConfigEntry.scope=worktree"]},
  "config origin": {"file": ["GitConfigEntry.origin=file"]}
}'

# The keys git does not document that the fixture sets, which each section's catch-all, other-keys, holds: gh's
# record of the repository a remote resolved to, and VS Code's of a branch's base.
config_catch_all='{
  "remote.*.gh-resolved": ["GitRemoteConfig.other-keys"],
  "branch.*.vscode-merge-base": ["GitBranchConfig.other-keys"]
}'

# A file of a git directory, a ref's namespace and kind, a worktree's HEAD, and each key of git worktree list
# --porcelain. The object store, its loose objects and its packs, is GitDir.objects, and the messages git commit and
# git merge leave are fields of GitWorktreeDir. A file may be here or on git_dir_unmodelled, never on both. branches/
# is here though the fixture may not show it: the templates of some gits, as some Linux distributions ship them, make
# it empty in every new git directory, and GitDir.legacy-remotes names it.
git_dir_names='{
  "common dir file": {
    "config": ["GitDir.config"], "description": ["GitDir.description"], "hooks": ["GitDir.hooks"],
    "refs": ["GitDir.refs"], "packed-refs": ["GitDir.refs", "GitDir.packed-refs-traits"],
    "branches": ["GitDir.legacy-remotes"],
    "worktrees": ["GitDir.worktree-dirs"], "modules": ["GitSubmodule.git-dir"], "shallow": ["GitDir.shallow"],
    "info/exclude": ["GitDir.exclude"], "info/attributes": ["GitDir.attributes"], "info/grafts": ["GitDir.grafts"],
    "info/refs": ["GitDir.info-refs"], "info/sparse-checkout": ["GitWorktreeDir.sparse-checkout"],
    "objects/info/alternates": ["GitDir.alternates"], "objects/info/http-alternates": ["GitDir.http-alternates"],
    "objects/info/packs": ["GitDir.packs"], "objects/??": ["GitDir.objects"], "objects/pack": ["GitDir.objects"],
    "logs/refs": ["GitRef.reflog"], "COMMIT_EDITMSG": ["GitWorktreeDir.commit-message-draft"],
    "MERGE_MSG": ["GitWorktreeDir.merge-message"], "MERGE_MODE": ["GitWorktreeDir.merge-mode"],
    "HEAD": ["GitWorktreeDir.head"], "index": ["GitWorktreeDir.index"], "logs/HEAD": ["GitWorktreeDir.head-log"],
    "config.worktree": ["GitWorktreeDir.config"], "ORIG_HEAD": ["GitWorktreeDir.root-refs"],
    "MERGE_HEAD": ["GitWorktreeDir.root-refs"], "AUTO_MERGE": ["GitWorktreeDir.root-refs"],
    "FETCH_HEAD": ["GitWorktreeDir.root-refs", "GitRootRef.fetched"]},
  "linked worktree dir file": {
    "commondir": ["GitWorktreeAdmin.commondir"], "gitdir": ["GitWorktreeAdmin.gitdir"],
    "locked": ["GitWorktreeAdmin.locked", "GitWorktreeAdmin.lock-reason"],
    "HEAD": ["GitWorktreeDir.head"], "index": ["GitWorktreeDir.index"], "logs/HEAD": ["GitWorktreeDir.head-log"],
    "refs": ["GitWorktreeDir.refs"], "config.worktree": ["GitWorktreeDir.config"],
    "info/sparse-checkout": ["GitWorktreeDir.sparse-checkout"], "ORIG_HEAD": ["GitWorktreeDir.root-refs"],
    "MERGE_HEAD": ["GitWorktreeDir.root-refs"], "AUTO_MERGE": ["GitWorktreeDir.root-refs"],
    "COMMIT_EDITMSG": ["GitWorktreeDir.commit-message-draft"], "MERGE_MSG": ["GitWorktreeDir.merge-message"],
    "MERGE_MODE": ["GitWorktreeDir.merge-mode"]},
  "ref namespace": {"refs/heads/": ["GitRef.kind=branch"], "refs/remotes/": ["GitRef.kind=remote-tracking"],
                    "refs/tags/": ["GitRef.kind=tag"], "refs/notes/": ["GitRef.kind=note"],
                    "refs/stash": ["GitRef.kind=stash"]},
  "ref kind": {"symbolic": ["GitRef.symref", "GitRef.symref-of"], "annotated tag": ["GitRef.tag-kind=annotated"],
               "lightweight tag": ["GitRef.tag-kind=lightweight"],
               "remote-tracking": ["GitRef.remote", "GitRef.branch"]},
  "worktree HEAD": {"symbolic": ["GitHead.Symbolic"], "detached": ["GitHead.Detached"],
                    "unborn": ["GitHead.Unborn", "GitUnbornRef.name"]},
  "worktree list key": {"worktree": ["GitWorktreeDir.worktree-path"], "HEAD": ["GitWorktreeDir.head"],
                        "branch": ["GitHead.Symbolic"], "detached": ["GitHead.Detached"], "bare": ["GitDir.bare"],
                        "locked": ["GitWorktreeAdmin.locked", "GitWorktreeAdmin.lock-reason"],
                        "prunable": ["GitWorktreeAdmin.prunable", "GitWorktreeAdmin.prune-reason"]}
}'

# What a git directory holds that is not git's, each with its reason. An entry that the fixture no longer shows fails,
# so the list holds only what is still written.
git_dir_unmodelled='{
  "common dir file": {
    "kit": "kit'"'"'s own directory, where kit keeps its state for the repository, and not git'"'"'s"}
}'

# The index format's own names: the signature, the version, each entry's stage, flags, and mode, and each extension's
# signature. An entry's mode is the octal of the number the index stores, 40000 for a sparse directory, which git
# ls-files --stage prints padded as 040000.
index_names='{
  "index signature": {"DIRC": ["GitIndex.signature=DIRC"]},
  "index version": {"2": ["GitIndex.version=2"], "3": ["GitIndex.version=3"], "4": ["GitIndex.version=4"]},
  "index entry stage": {"0": ["GitIndexEntry.stage=0"], "1": ["GitIndexEntry.stage=1"],
                        "2": ["GitIndexEntry.stage=2"], "3": ["GitIndexEntry.stage=3"]},
  "index entry flag": {"assume-valid": ["GitIndexEntry.assume-valid"], "extended": ["GitIndexEntry.extended"],
                       "skip-worktree": ["GitIndexEntry.skip-worktree"],
                       "intent-to-add": ["GitIndexEntry.intent-to-add"]},
  "index entry mode": {"100644": ["GitIndexEntry.mode=100644"], "100755": ["GitIndexEntry.mode=100755"],
                       "120000": ["GitIndexEntry.mode=120000"], "160000": ["GitIndexEntry.mode=160000"],
                       "40000": ["GitIndexEntry.mode=40000"]},
  "index extension": {"TREE": ["GitIndex.cache-tree", "GitCacheTree.id"], "REUC": ["GitIndex.resolve-undo"],
                      "UNTR": ["GitIndex.untracked-cache"], "link": ["GitIndex.shared"], "sdir": ["GitIndex.sparse"],
                      "FSMN": ["GitIndex.fsmonitor-version"], "EOIE": ["GitIndex.entries-end"],
                      "IEOT": ["GitIndex.entry-blocks"]}
}'

# What each walk must observe, the cases the fixture is built to hold, as [kind, name]. A check asserts its reach before
# it judges the observations, so a walk that lost a case, or observed nothing, fails.
object_reach='[
  ["commit header", "mergetag"], ["commit header", "encoding"], ["commit header", "gpgsig"],
  ["commit header", "x-model-extra"], ["commit part", "trailers"], ["tag part", "signature"],
  ["signature armor", "SSH SIGNATURE"], ["signature status", "G"], ["tree entry mode", "100755"],
  ["tree entry mode", "120000"], ["tree entry mode", "40000"], ["tree entry mode", "160000"]
]'
config_reach='[
  ["config scope", "worktree"], ["config key", "remote.*.pushurl"], ["config key", "remote.*.fetch"],
  ["config key", "branch.*.remote"], ["config key", "submodule.*.url"], ["config key", "core.worktree"],
  ["gitmodules key", "submodule.*.path"]
]'
git_dir_reach='[
  ["worktree HEAD", "detached"], ["worktree HEAD", "unborn"], ["ref namespace", "refs/stash"],
  ["ref namespace", "refs/notes/"], ["ref kind", "symbolic"], ["ref kind", "lightweight tag"],
  ["worktree list key", "locked"], ["worktree list key", "prunable"], ["linked worktree dir file", "locked"],
  ["common dir file", "MERGE_MODE"]
]'
index_reach='[
  ["index entry stage", "1"], ["index entry stage", "3"], ["index entry flag", "intent-to-add"],
  ["index extension", "REUC"], ["index extension", "TREE"], ["index version", "3"]
]'

# The value each option of a read-by takes, from the fixture: the workspace file's one group. An option this does
# not name is given as a flag.
verb_values='{"--show": "model"}'

# Where each verb runs, from the world's root; every other verb runs at the desk, repo. facts reads the commits past
# the base of a branch, and --current outside a repository says the last group used, and why.
verb_places='{"facts": "worktrees/feature", "workspaces --current": "."}'

# The verbs whose rows feed the Code entities, and the keys a row of each prints that no read-by of that verb names,
# each with its reason. A row's own keys are the rows contract's (docs/apps.md, "Rows"). A key that is another
# entity's field is named once, by the read-by of the verb that prints that entity. Each Entity.member a reason names
# must be a relation of the model or a held field, so a reason cannot outlive the member it leans on.
code_verbs='[
  "workspace repos", "workspace remotes", "workspace branches", "workspace worktrees", "workspace commits",
  "workspace tags", "workspaces", "workspaces --show", "workspaces --current", "changes", "changes reviews",
  "changes checks", "changes merged", "flow changes"
]'
code_allowlist='{
  "workspace repos": {
    "ahead": "the desk worktree'"'"'s Worktree.base, which workspace worktrees prints",
    "behind": "the desk worktree'"'"'s Worktree.base, which workspace worktrees prints",
    "branch": "the desk worktree'"'"'s Worktree.branch, which workspace worktrees prints",
    "branches": "the Branch.name of each branch no worktree has, which workspace branches prints",
    "remotes": "each remote'"'"'s Remote.name, Remote.url, and Remote.forge, which workspace remotes prints",
    "worktrees": "each linked worktree'"'"'s Worktree.branch and Worktree.path, which workspace worktrees prints",
    "error": "the line kit says when it could not read the member, of no entity",
    "source": "the rows contract'"'"'s source, the tool kit read the row from"},
  "workspace remotes": {
    "key": "the row'"'"'s key, Remote.name again",
    "organization": "the Organization.name of the remote'"'"'s repository, which workspace repos prints",
    "host": "the Repository.host of the remote'"'"'s repository, which workspace repos prints",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "source": "the rows contract'"'"'s source, the tool kit read the row from"},
  "workspace branches": {
    "key": "the row'"'"'s key, the Branch.name, with the Branch.remote-name before it on a remote row",
    "local": "the Branch.downstream branches, by Branch.name",
    "commit": "the Branch.tip, by its Commit.short-id, which workspace commits prints",
    "age": "the Commit.age of the Branch.tip, which workspace commits prints",
    "subject": "the Commit.subject of the Branch.tip, which workspace commits prints",
    "worktree": "the Worktree.path of the Branch.worktree, or of the Branch.downstream branches on a remote row",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the tool kit read the row from"},
  "workspace worktrees": {
    "key": "the row'"'"'s key, Worktree.path again",
    "track": "the Branch.track of the worktree'"'"'s branch, which workspace branches prints",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the tool kit read the row from"},
  "workspace commits": {
    "branches": "the Commit.branches, by Branch.name",
    "worktrees": "the Commit.worktrees, by Worktree.path",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the tool kit read the row from"},
  "workspace tags": {
    "key": "the row'"'"'s key, Tag.name again",
    "commit": "the Tag.commit, by its Commit.short-id, which workspace commits prints",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the tool kit read the row from"},
  "workspaces": {
    "file": "the workspace file'"'"'s path, a setting of the file and not of a workspace",
    "roots": "the workspace file'"'"'s roots, a setting of the file and not of a workspace",
    "favorites": "the favorites by Workspace.name, which Workspace.favorite holds for each workspace"},
  "workspaces --show": {
    "name": "Workspace.name, which workspaces prints",
    "members": "the Workspace.members, by the Repository.name, Repository.desk, and Remote.url workspace repos prints"},
  "workspaces --current": {
    "kind": "Workspace.kind, which workspaces --show prints, or none where kit starts on no workspace",
    "name": "Workspace.name, which workspaces prints",
    "member": "the Repository.name of a workspace of one repository, which workspace repos prints",
    "checkout": "the Repository.desk of a workspace of one repository, which workspace repos prints",
    "members": "each Workspace.members, as workspaces --show prints them",
    "groups": "the groups that hold the repository, by Workspace.name and Workspace.member-count",
    "workspaces": "each workspace by Workspace.name and Workspace.member-count, which workspaces prints",
    "favorites": "each favorite by Workspace.name, Workspace.kind, Workspace.member-count, and Repository.desk"},
  "changes": {
    "contract": "the version of the rows contract",
    "stages": "the names of the stages",
    "reviews": "the document of the reviews stage, whose rows changes reviews prints",
    "checks": "the document of the checks stage, whose rows changes checks prints",
    "merged": "the document of the merged stage, whose rows changes merged prints"},
  "changes reviews": {
    "key": "the row'"'"'s key, the Change.number and the Review.login",
    "change": "the Review.change, by its Change.number, which flow changes prints",
    "title": "the Change.title of the Review.change, which flow changes prints",
    "unresolved": "the Change.unresolved of the Review.change, which flow changes prints",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the forge kit read the row from"},
  "changes checks": {
    "key": "the row'"'"'s key, the Change.number and the check'"'"'s name",
    "change": "the change the check ran for, by its Change.number, which flow changes prints",
    "title": "the Change.title of the change the check ran for, which flow changes prints",
    "name": "a check run'"'"'s: the Delivery domain'"'"'s Check and Run, which this model does not unpack yet",
    "workflow": "a check run'"'"'s: the Delivery domain'"'"'s Check and Run, which this model does not unpack yet",
    "event": "a check run'"'"'s: the Delivery domain'"'"'s Check and Run, which this model does not unpack yet",
    "verdict": "a check run'"'"'s: the Delivery domain'"'"'s Check and Run, which this model does not unpack yet",
    "at": "a check run'"'"'s: the Delivery domain'"'"'s Check and Run, which this model does not unpack yet",
    "took": "a check run'"'"'s: the Delivery domain'"'"'s Check and Run, which this model does not unpack yet",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the forge kit read the row from"},
  "changes merged": {
    "key": "the row'"'"'s key, Change.number again",
    "number": "Change.number, which flow changes prints",
    "title": "Change.title, which flow changes prints",
    "author": "Change.author, which flow changes prints",
    "branch": "Change.branch-name, which flow changes prints",
    "named": "Change.named, which flow changes prints",
    "links": "the rows contract'"'"'s links, to pages and other rows",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints",
    "source": "the rows contract'"'"'s source, the forge kit read the row from"},
  "flow changes": {
    "source": "the forge the change is on, the rows contract'"'"'s source",
    "reviewers": "the Change.reviews, by Review.login, Review.state, and Review.at, which changes reviews prints",
    "labels": "the Work domain'"'"'s labels, which this model does not unpack yet",
    "closes": "the Work domain'"'"'s issues the change closes, which this model does not unpack yet",
    "runs": "the Delivery domain'"'"'s check runs, which this model does not unpack yet",
    "organization": "Organization.name, which workspace repos prints",
    "repository": "Repository.short-name, which workspace remotes prints"}
}'

# The held fields whose read-by kit cannot print in this world, each with its reason. The list may hold no more than
# unverified_most, so it cannot grow unseen.
unverified='{}'
unverified_most=0

setup_file() {
  world-make model model-world
}

# model-world builds the fixture in the world's root, the fake gh, and the workspace file, writes the model to
# model.json, and runs the verbs, writing what each printed to outputs.json. world-make runs it in a list, where errexit
# stops nothing, so each step returns on its own failure.
model-world() {
  local root=${PWD}
  "${BATS_TEST_DIRNAME}/fixtures/model-repo/build" "${root}" || return 1
  model-of "${kit_root}/modules/model" > "${root}/model.json" || return 1
  forge-world "${root}/fake" || return 1
  printf 'roots: [%s]\nworkspaces:\n  model:\n    repos: [github.com/o/r]\n' "${root}" \
    > "${XDG_CONFIG_HOME}/kit/workspaces.yml" || return 1
  "${kit_root}/bin/kit" workspaces --favorite=model || return 1
  "${kit_root}/bin/kit" workspaces --use=./repo || return 1
  "${kit_root}/bin/kit" workspaces --use=model || return 1
  run-verbs "${root}"
}

# model-of <dir> prints the model built from the model files under <dir>, with no repository's additions.
model-of() {
  local loaded
  loaded=$(kit_bash_modules=model kit-bash "model:load '$1' '${BATS_FILE_TMPDIR}/no-repository-model'") || return 1
  jq -L "${kit_root}/modules/jq" 'import "model" as model; model::build' <<<"${loaded}"
}

# broken-model <file> <yq expression> copies the release's model, applies the expression to <file> of the copy, and
# prints the path of the model built from the copy.
broken-model() {
  local copy=${BATS_TEST_TMPDIR}/model
  rm -rf "${copy}"
  cp -R "${kit_root}/modules/model" "${copy}"
  yq --inplace "$2" "${copy}/$1" || return 1
  model-of "${copy}" > "${BATS_TEST_TMPDIR}/broken.json" || return 1
  printf '%s\n' "${BATS_TEST_TMPDIR}/broken.json"
}

# forge-world <dir> stands the fake gh in, first on PATH, with answers for o/r: change 3 on feature, which closes
# issue 9, asks bob for a review that carol approved, has one unresolved thread, a label, a body that names AB#12, and
# the runs a, failed, and b, passed; change 4, a draft from mal's fork; and change 2, merged by ada.
forge-world() {
  export FAKE_DIR=$1
  mkdir -p "${FAKE_DIR}/bin"
  ln -sf "${BATS_TEST_DIRNAME}/fakes/fake-tool" "${FAKE_DIR}/bin/gh"
  export PATH="${FAKE_DIR}/bin:${PATH}"
  printf '{"login": "ada"}\n' > "${FAKE_DIR}/user.json"
  printf '{"nameWithOwner": "o/r", "url": "https://github.com/o/r"}\n' > "${FAKE_DIR}/repo.json"
  printf '[]\n' > "${FAKE_DIR}/none.json"
  printf '[{"number": 9, "title": "Feature", "assignees": [{"login": "ada"}], "createdAt": "2026-09-25T09:00:00Z"}]\n' \
    > "${FAKE_DIR}/issues.json"
  cat > "${FAKE_DIR}/open-prs.json" <<'JSON'
{"data": {"repository": {"nameWithOwner": "o/r",
 "issues": {"nodes": [{"number": 9, "assignees": {"nodes": [{"login": "ada"}]}}]},
 "pullRequests": {"nodes": [{
  "number": 3, "title": "Feature", "url": "https://github.com/o/r/pull/3", "isDraft": false,
  "headRefName": "feature", "body": "Closes AB#12",
  "createdAt": "2026-10-01T09:00:00Z", "mergeStateStatus": "CLEAN", "reviewDecision": null,
  "author": {"login": "ada"}, "labels": {"nodes": [{"name": "bug", "color": "d73a4a"}]},
  "closingIssuesReferences": {"nodes": [{"number": 9, "title": "Feature", "createdAt": "2026-09-25T09:00:00Z",
    "url": "https://github.com/o/r/issues/9", "repository": {"nameWithOwner": "o/r"}}]},
  "reviewRequests": {"totalCount": 1, "nodes": [{"requestedReviewer": {"login": "bob"}}]},
  "latestReviews": {"totalCount": 1, "nodes": [
    {"author": {"login": "carol"}, "state": "APPROVED", "submittedAt": "2026-10-02T09:00:00Z"}]},
  "reviewThreads": {"nodes": [{"isResolved": false}]},
  "commits": {"nodes": [{"commit": {"committedDate": "2026-10-01T10:00:00Z", "author": {"user": {"login": "ada"}},
    "statusCheckRollup": {"contexts": {"nodes": [
      {"__typename": "CheckRun", "name": "a", "status": "COMPLETED", "conclusion": "FAILURE",
       "startedAt": "2026-10-01T10:00:00Z", "completedAt": "2026-10-01T10:05:00Z"},
      {"__typename": "CheckRun", "name": "b", "status": "COMPLETED", "conclusion": "SUCCESS",
       "startedAt": "2026-10-01T10:00:10Z", "completedAt": "2026-10-01T10:01:00Z"}]}}}}]}},
 {"number": 4, "title": "From a fork", "url": "https://github.com/o/r/pull/4", "isDraft": true,
  "headRefName": "feature", "isCrossRepository": true, "headRepositoryOwner": {"login": "mal"}, "body": "",
  "createdAt": "2026-10-03T09:00:00Z", "mergeStateStatus": "CLEAN", "reviewDecision": null,
  "author": {"login": "mal"}, "labels": {"nodes": []}, "closingIssuesReferences": {"nodes": []},
  "reviewThreads": {"nodes": []}, "commits": {"nodes": [{"commit": {"statusCheckRollup": null}}]}}]}}}}
JSON
  cat > "${FAKE_DIR}/merged.json" <<'JSON'
{"data": {"repository": {"pullRequests": {"totalCount": 1, "nodes": [
  {"number": 2, "title": "Docs", "url": "https://github.com/o/r/pull/2", "headRefName": "docs",
   "mergedAt": "2026-10-03T09:00:00Z", "updatedAt": "2026-10-03T09:00:00Z", "author": {"login": "bob"},
   "mergedBy": {"login": "ada"}}]}}}}
JSON
  printf 'HTTP/2.0 200 OK\r\nETag: W/"m1"\r\n\r\n[]\n' > "${FAKE_DIR}/marks-200.txt"
  printf '%s\t%s\n' 'api user*' user.json 'repo view*' repo.json 'pr list --head*' none.json \
    'issue list --state open --limit 10000 --json *' issues.json 'api --include*' marks-200.txt \
    'api graphql*states: MERGED*' merged.json 'api graphql*' open-prs.json > "${FAKE_DIR}/gh.routes"
}

# model_jq defines, for jq, what the checks share:
#   - held: each held field, as {member, readby}; verb and key split a read-by into its verb words and its key
#   - rows: a verb's rows, the elements of an array or of .rows, else the document itself
#   - at($segments): every value at a key path, * any key of a mapping or any element of an array
#   - lacks($spec): why the model does not hold Entity.member, a field, relation, or variant, or Entity.field=value, a
#     value of the field's enum; nothing when it does
#   - unnamed($table; $seen): a line for each name git wrote that the table does not map, and for each entry whose
#     member the model lacks; the input is the model, and $seen the observations, each {kind, name, at}
# shellcheck disable=SC2016  # a jq program, whose $ names are jq's
model_jq='
  def held: [.entities | to_entries[] | .key as $e | (.value.fields // {}) | to_entries[]
             | select(.value.status == "held") | {member: "\($e).\(.key)", readby: (.value["read-by"] // "")}];
  def words: split(" ") | map(select(. != ""));
  def verb: words | .[:-1] | join(" ");
  def key: words | last;
  def rows: if type == "array" then .[] elif type == "object" and (.rows | type) == "array" then .rows[] else . end;
  def at($segments):
    if ($segments | length) == 0 then .
    elif $segments[0] == "*" then (if type == "object" or type == "array" then .[] else empty end) | at($segments[1:])
    elif type == "object" and has($segments[0]) then .[$segments[0]] | at($segments[1:])
    else empty end;
  def lacks($spec):
    . as $model
    | ($spec | capture("^(?<e>[^.]+)\\.(?<m>[^=]+)(=(?<v>.*))?$")) as $p
    | $model.entities[$p.e] as $entity
    | if $entity == null then "the model has no entity \($p.e)"
      elif $p.v == null then
        if ($entity.fields // {} | has($p.m)) or ($entity.relations // {} | has($p.m))
           or ($entity.variants // {} | has($p.m)) then empty
        else "\($p.e) has no field, relation, or variant \($p.m)" end
      elif ($entity.fields // {} | has($p.m) | not) then "\($p.e) has no field \($p.m)"
      elif ($entity.fields[$p.m].type | type) != "object" then "\($p.e).\($p.m) is not an enum"
      elif any($entity.fields[$p.m].type.enum[]; . == $p.v) then empty
      else "\($p.e).\($p.m) has no value \($p.v) in its enum" end;
  def unnamed($table; $seen):
    . as $model
    | ([$seen | group_by([.kind, .name])[] | .[0] | select($table[.kind][.name] == null)
        | "the model names nothing for the \(.kind) \(.name), which git wrote at \(.at)"]
       + [$table | to_entries[] | .key as $kind | .value | to_entries[] | .key as $name | .value[]
          | . as $spec | $model | lacks($spec)
          | "the \($kind) \($name) is held by \($spec), but \(.)"])
    | unique[];'

# unnamed <model> <table> <observations> prints a line for each observation the table does not map and each table
# entry the model lacks, and fails when it prints one.
unnamed() {
  local found
  found=$(jq --raw-output --argjson table "$2" --argjson seen "$(observations "$3")" "${model_jq}"'
    unnamed($table; $seen)' "$1")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

# config-table prints config_names with the catch-all's keys among the config keys.
config-table() {
  jq --null-input --argjson t "${config_names}" --argjson c "${config_catch_all}" '$t | .["config key"] += $c'
}

# catch-all-wrong <observations> [<catch-all>] prints a line for each key of the catch-all, config_catch_all unless
# given, that the fixture no longer sets, that config_names maps as a key git documents, or whose member is no
# section's other-keys, and fails when it prints one. So a documented key cannot hide in a catch-all.
catch-all-wrong() {
  local found
  found=$(jq --raw-output --argjson names "${config_names}" --argjson catch "${2:-${config_catch_all}}" '
    [.[] | select(.kind == "config key") | .name] as $seen
    | [$catch | to_entries[] | .key as $key
       | (select($seen | index([$key]) | not)
          | "config_catch_all holds \($key), which the fixture no longer sets"),
         (select($names["config key"] | has($key))
          | "config_catch_all holds \($key), which config_names maps as a key git documents"),
         (.value[] | select(test("^Git(Remote|Branch)Config\\.other-keys$") | not)
          | "config_catch_all gives \($key) to \(.), which is no section'"'"'s other-keys")]
    | unique[]' <<<"$(observations "$1")")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

# git-dir-table [<names> <unmodelled>] prints git_dir_names, or <names>, with each file git_dir_unmodelled, or
# <unmodelled>, holds mapped to no member, so the check passes it over. It fails, naming the file, for a file that is
# on both, because the second would hide the first's members from the check.
git-dir-table() {
  local names=${1:-${git_dir_names}} unmodelled=${2:-${git_dir_unmodelled}} both
  both=$(jq --raw-output --null-input --argjson t "${names}" --argjson u "${unmodelled}" '
    $u | to_entries[] | .key as $kind | .value | keys[] | . as $file | select($t[$kind] // {} | has($file))
    | "the \($kind) \(.) is both mapped in git_dir_names and on git_dir_unmodelled"')
  [[ -z "${both}" ]] || { printf '%s\n' "${both}" >&2; return 1; }
  jq --null-input --argjson t "${names}" --argjson u "${unmodelled}" \
    'reduce ($u | to_entries[]) as $e ($t; .[$e.key] += ($e.value | map_values([])))'
}

# unmodelled-stale <observations> [<unmodelled>] prints a line for each entry of git_dir_unmodelled, or
# <unmodelled>, that the fixture no longer shows, and fails when it prints one.
unmodelled-stale() {
  local found
  found=$(jq --raw-output --argjson u "${2:-${git_dir_unmodelled}}" '
    [.[] | [.kind, .name]] as $seen
    | $u | to_entries[] | .key as $kind | .value | keys[] | . as $file | select($seen | index([[$kind, $file]]) | not)
    | "git_dir_unmodelled holds the \($kind) \(.), which the fixture no longer shows"' <<<"$(observations "$1")")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

# reaches <observations> <reach> prints a line for each [kind, name] of the reach that no observation holds, and fails
# when it prints one. Each check asserts its reach first, so a walk that lost what the fixture is built to hold fails,
# and never passes over nothing.
reaches() {
  local found
  found=$(jq --raw-output --argjson reach "$2" '
    [.[] | [.kind, .name]] as $seen
    | $reach[] | select(. as $case | $seen | index([$case]) | not)
    | "the observations hold no \(.[0]) \(.[1]), which the fixture is built to hold"' <<<"$(observations "$1")")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

# fixture-git <dir> <git argument>… runs git in <dir> of the world, with no configuration but the repository's, and
# prints what it prints. It returns 0 or 1 as git does, and 2, after it prints the command and what git wrote on
# stderr, when git wrote anything there or exited above 1. Every call is a read-only plumbing read of a fixed fixture,
# so any stderr is a failure: an error git reports with status 0, as %G? does, or a warning a later git adds, ends the
# walk, naming the call. A caller that reads git's output takes it from a variable or a file it set with || return,
# never from a pipe or a process substitution, whose status bats would lose. A caller that reads git's answer from
# its status, as symbolic-ref --quiet gives 1 for a HEAD that is not symbolic, tells 1 from 2 and returns on 2.
fixture-git() {
  local err=${BATS_TEST_TMPDIR}/fixture-git.err status=0
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "${world}/$1" "${@:2}" \
    2> "${err}" || status=$?
  if [[ -s "${err}" ]] || (( status > 1 ))
  then
    printf 'git -C %s %s wrote on stderr, or exited %s:\n' "$1" "${*:2}" "${status}" >&2
    cat "${err}" >&2
    return 2
  fi
  return "${status}"
}

# seen <kind> <name> <at> prints one observation, its three parts tab-separated.
seen() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

# observations <file> prints the observations of the file, one a line as seen prints them, as a JSON array of
# {kind, name, at}.
observations() {
  jq --raw-input --slurp 'split("\n") | map(select(. != "") | split("\t") | {kind: .[0], name: .[1], at: .[2]})' "$1"
}

# headers-seen <kind> <part kind> <at> <content> prints an observation for each header of an object's content, a
# commit or a tag, for the message, for the trailers it ends with, and, for a tag, for the signature at its end, and
# the armor of each signature. A mergetag's value is a tag, whose own headers it prints as a tag's.
headers-seen() {
  local kind=$1 part=$2 at=$3 content=$4 line name value='' header='' message='' in_message=false trailers
  while IFS= read -r line
  do
    if [[ "${in_message}" == true ]]
    then
      message+="${line}"$'\n'
    elif [[ -z "${line}" ]]
    then
      in_message=true
    elif [[ "${line}" == ' '* ]]
    then
      value+="${line# }"$'\n'
    else
      [[ -z "${header}" ]] || header-value-seen "${header}" "${value}" "${at}" || return 1
      name=${line%% *}
      header=${name}
      value="${line#"${name}"}"$'\n'
      value=${value# }
      seen "${kind}" "${name}" "${at}"
      [[ "${kind}" != "tag header" || "${name}" != type ]] || seen "tag type" "${line#type }" "${at}"
    fi
  done <<<"${content}"
  [[ -z "${header}" ]] || header-value-seen "${header}" "${value}" "${at}" || return 1
  [[ -z "${message}" ]] || seen "${part}" message "${at}"
  if [[ "${part}" == "tag part" && "${message}" == *'-----BEGIN '*'-----'* ]]
  then
    seen "${part}" signature "${at}"
    armor-seen "${message}" "${at}"
  fi
  trailers=$(fixture-git repo interpret-trailers --parse <<<"${message}") || return 1
  [[ -z "${trailers}" ]] || seen "${part}" trailers "${at}"
}

# header-value-seen <header> <value> <at> prints what a header's value holds: a signature's armor, and a mergetag's
# tag, as a tag's headers and parts.
header-value-seen() {
  case "$1" in
    (gpgsig | gpgsig-sha256) armor-seen "$2" "$3" ;;
    (mergetag) headers-seen "tag header" "tag part" "the mergetag of $3" "$2" ;;
  esac
}

# armor-seen <text> <at> prints the kind of each signature's armor in the text: SSH SIGNATURE, PGP SIGNATURE, or
# SIGNED MESSAGE.
armor-seen() {
  local line
  while IFS= read -r line
  do
    [[ "${line}" =~ ^-----BEGIN\ (.*)-----$ ]] && seen "signature armor" "${BASH_REMATCH[1]}" "$2"
  done <<<"$1"
  return 0
}

# objects-seen prints an observation for every object the fixture's repositories hold, reachable or not, and for
# every header, part, and tree entry mode of each, and each signature's status as %G? checks it: in the desk with its
# stash and notes, the clone stopped in a merge, and the submodule.
objects-seen() {
  local dir id type mode status objects content modes statuses
  for dir in repo conflict repo/sub
  do
    objects=$(fixture-git "${dir}" cat-file --batch-all-objects --batch-check='%(objectname) %(objecttype)') \
      || return 1
    while read -r id type
    do
      [[ -n "${id}" ]] || continue
      seen "object type" "${type}" "${dir} ${id}"
      case "${type}" in
        (commit | tag)
          content=$(fixture-git "${dir}" cat-file "${type}" "${id}") || return 1
          headers-seen "${type} header" "${type} part" "${dir} ${id}" "${content}" || return 1
          ;;
        (tree)
          modes=$(fixture-git "${dir}" ls-tree --format='%(objectmode)' "${id}") || return 1
          while read -r mode
          do
            [[ -z "${mode}" ]] || seen "tree entry mode" "${mode#0}" "${dir} ${id}"
          done <<<"${modes}"
          ;;
      esac
    done <<<"${objects}"
    statuses=$(fixture-git "${dir}" log --all --format='%H %G?') || return 1
    while read -r id status
    do
      [[ -n "${id}" ]] || continue
      [[ "${status}" == N ]] || seen "signature status" "${status}" "${dir} ${id}"
    done <<<"${statuses}"
  done
}

# config-seen prints an observation for every key of the configuration each worktree of the fixture reads, with its
# scope and origin, and for every key of the desk's .gitmodules. A key's subsection is written * in a remote's, a
# branch's, or a submodule's section. git prints NUL bytes, which a variable cannot hold, so its output goes to a file.
config-seen() {
  local dir list=${BATS_TEST_TMPDIR}/config.list
  for dir in repo worktrees/feature worktrees/detached worktrees/locked worktrees/unborn conflict repo/sub
  do
    fixture-git "${dir}" config --list --show-scope --show-origin --null > "${list}" || return 1
    jq --raw-input --slurp --raw-output --arg dir "${dir}" '
      def general: (split(".")) as $p
        | if ($p | length) > 2 and ($p[0] | IN("remote", "branch", "submodule"))
          then "\($p[0]).*.\($p[-1])" else . end;
      split("\u0000") | [range(0; (length / 3 | floor)) as $i | .[3 * $i:3 * $i + 3]][]
      | (.[2] | split("\n")[0]) as $key | "\($dir): \(.[0]) \(.[1])" as $at
      | ["config key", ($key | general), $at], ["config scope", .[0], $at],
        ["config origin", (.[1] | split(":")[0]), $at]
      | @tsv' "${list}" || return 1
  done
  fixture-git repo config --file .gitmodules --list --null > "${list}" || return 1
  jq --raw-input --slurp --raw-output '
    split("\u0000")[] | select(. != "") | split("\n")[0] | split(".")
    | ["gitmodules key", "\(.[0]).*.\(.[-1])", "repo/.gitmodules"] | @tsv' "${list}"
}

# dir-files-seen <kind> <dir> prints an observation for each file of a git directory: its name, or under info/,
# logs/, and objects/ its path, a loose object's directory written objects/??, and under objects/info/ each file.
dir-files-seen() {
  local kind=$1 dir=$2 path name inner file
  [[ -d "${world}/${dir}" ]] || { echo "dir-files-seen: ${dir} is not a directory of the fixture" >&2; return 1; }
  for path in "${world}/${dir}"/* "${world}/${dir}"/.[!.]*
  do
    [[ -e "${path}" ]] || continue
    name=${path##*/}
    case "${name}" in
      (info | logs)
        for inner in "${path}"/*
        do
          [[ ! -e "${inner}" ]] || seen "${kind}" "${name}/${inner##*/}" "${dir}"
        done
        ;;
      (objects)
        for inner in "${path}"/*
        do
          case "${inner##*/}" in
            ([0-9a-f][0-9a-f]) seen "${kind}" "objects/??" "${dir}" ;;
            (info)
              for file in "${inner}"/*
              do
                [[ ! -e "${file}" ]] || seen "${kind}" "objects/info/${file##*/}" "${dir}"
              done
              ;;
            (*) seen "${kind}" "objects/${inner##*/}" "${dir}" ;;
          esac
        done
        ;;
      (*) seen "${kind}" "${name}" "${dir}" ;;
    esac
  done
}

# heads-seen <worktree>… prints how the HEAD of each worktree of the world stands: symbolic, detached, or unborn.
# Each worktree first proves it is one, with rev-parse --git-dir. Then symbolic-ref --quiet HEAD answers 0 for a
# symbolic HEAD and 1, with nothing on stderr, for a detached one, and rev-parse --verify --quiet HEAD answers 0 for a
# HEAD with a commit and 1 for an unborn one. fixture-git's 2, git's failure, ends it, never an observation.
heads-seen() {
  local wt symbolic verified
  for wt in "$@"
  do
    fixture-git "${wt}" rev-parse --git-dir >/dev/null || return 1
    symbolic=0
    fixture-git "${wt}" symbolic-ref --quiet HEAD >/dev/null || symbolic=$?
    (( symbolic < 2 )) || return 1
    if (( symbolic == 1 ))
    then
      seen "worktree HEAD" detached "${wt}"
      continue
    fi
    verified=0
    fixture-git "${wt}" rev-parse --verify --quiet HEAD >/dev/null || verified=$?
    (( verified < 2 )) || return 1
    if (( verified == 0 ))
    then
      seen "worktree HEAD" symbolic "${wt}"
    else
      seen "worktree HEAD" unborn "${wt}"
    fi
  done
}

# git-dirs-seen prints an observation for each file of the fixture's git directories, the common ones and each linked
# worktree's; for each ref, its namespace and kind; for each worktree, how its HEAD stands; and each key of git
# worktree list --porcelain. Any git call that fails ends it, as heads-seen says for the HEADs.
git-dirs-seen() {
  local dir ref type symref wt line refs list
  for dir in repo/.git conflict/.git repo/.git/modules/sub
  do
    dir-files-seen "common dir file" "${dir}" || return 1
  done
  for dir in "${world}"/repo/.git/worktrees/*
  do
    dir-files-seen "linked worktree dir file" "repo/.git/worktrees/${dir##*/}" || return 1
  done
  for dir in repo conflict repo/sub
  do
    refs=$(fixture-git "${dir}" for-each-ref --format='%(refname)%09%(objecttype)%09%(symref)') || return 1
    while IFS=$'\t' read -r ref type symref
    do
      [[ -n "${ref}" ]] || continue
      case "${ref}" in
        (refs/stash) seen "ref namespace" refs/stash "${dir} ${ref}" ;;
        (*) seen "ref namespace" "$(cut -d / -f 1-2 <<<"${ref}")/" "${dir} ${ref}" ;;
      esac
      [[ -z "${symref}" ]] || seen "ref kind" symbolic "${dir} ${ref}"
      [[ "${ref}" != refs/remotes/* || -n "${symref}" ]] || seen "ref kind" remote-tracking "${dir} ${ref}"
      if [[ "${ref}" == refs/tags/* ]]
      then
        if [[ "${type}" == tag ]]
        then
          seen "ref kind" "annotated tag" "${dir} ${ref}"
        else
          seen "ref kind" "lightweight tag" "${dir} ${ref}"
        fi
      fi
    done <<<"${refs}"
  done
  heads-seen repo worktrees/feature worktrees/detached worktrees/locked worktrees/unborn conflict || return 1
  list=$(fixture-git repo worktree list --porcelain) || return 1
  while IFS= read -r line
  do
    [[ -z "${line}" ]] || seen "worktree list key" "${line%% *}" "repo: ${line}"
  done <<<"${list}"
}

# index_jq reads an index file's bytes, as numbers, and gives an observation for its signature, its version, each
# entry's stage, flags, and mode, and each extension. It reads the entries of versions 2 and 3, whose layout is fixed;
# a version 4 index is an observation of its own, which no table maps, so the check names it. $hash is the length of
# an object id, 20 for SHA-1.
# shellcheck disable=SC2016  # a jq program, whose $ names are jq's
index_jq='
  def u16($i): .[$i] * 256 + .[$i + 1];
  def u32($i): ((.[$i] * 256 + .[$i + 1]) * 256 + .[$i + 2]) * 256 + .[$i + 3];
  def bit($n; $b): (($n / $b) | floor) % 2 == 1;
  def octal: [recurse(if . >= 8 then (. / 8 | floor) else empty end) | . % 8] | reverse | map(tostring) | join("");
  def entries($hash; $count):
    def step($offset; $left):
      if $left == 0 then {end: $offset}
      else
        u16($offset + 40 + $hash) as $flags
        | bit($flags; 16384) as $extended
        | (if $extended then u16($offset + 42 + $hash) else 0 end) as $more
        | ($offset + 42 + $hash + (if $extended then 2 else 0 end)) as $name
        | (if $flags % 4096 < 4095 then $flags % 4096 else (.[$name:] | indices(0)[0]) end) as $length
        | {stage: (($flags / 4096 | floor) % 4 | tostring), mode: (u32($offset + 24) | octal),
           flags: ([if bit($flags; 32768) then "assume-valid" else empty end,
                    if $extended then "extended" else empty end,
                    if bit($more; 16384) then "skip-worktree" else empty end,
                    if bit($more; 8192) then "intent-to-add" else empty end]
                   + [range(0; 13) as $b | select(bit($more; pow(2; $b))) | "extended flag bit \($b)"])},
          step($offset + ((($name - $offset + $length + 8) / 8 | floor) * 8); $left - 1)
      end;
    step(12; $count);
  def extensions($from; $hash):
    def step($offset):
      if $offset >= length - $hash then empty
      else {extension: (.[$offset:$offset + 4] | implode)}, step($offset + 8 + u32($offset + 4)) end;
    step($from);
  def index_seen($hash; $at):
    u32(4) as $version
    | {kind: "index signature", name: (.[0:4] | implode), at: $at},
      {kind: "index version", name: ($version | tostring), at: $at},
      if $version == 4 then {kind: "index version 4 entries, which this check does not read", name: "4", at: $at}
      else
        [entries($hash; u32(8))] as $read
        | ($read[] | select(has("stage"))
           | {kind: "index entry stage", name: .stage, at: $at}, {kind: "index entry mode", name: .mode, at: $at},
             (.flags[] | {kind: "index entry flag", name: ., at: $at})),
          (extensions($read[-1].end; $hash) | {kind: "index extension", name: .extension, at: $at})
      end;'

# indexes-seen prints the observations of every index file of the fixture: the desk's, each linked worktree's, the
# clone's stopped in a merge, and the submodule's.
indexes-seen() {
  local file bytes
  for file in "${world}"/repo/.git/index "${world}"/repo/.git/worktrees/*/index "${world}"/conflict/.git/index \
    "${world}"/repo/.git/modules/sub/index
  do
    [[ -f "${file}" ]] || continue
    bytes=$(od -An -v -tu1 "${file}") || return 1
    jq --raw-input --slurp --raw-output --arg at "${file#"${world}/"}" "${index_jq}"'
      [splits("[ \n]+") | select(. != "") | tonumber] | index_seen(20; $at) | [.kind, .name, .at] | @tsv' \
      <<<"${bytes}" || return 1
  done
}

# held-unprinted <model> [<unverified> <most>] prints a line for each held field whose read-by its verb does not
# print, or prints only as null in every row, or whose key is * alone, which names no key; for each verb that failed or
# printed no JSON; for each entry of the unverified list, unverified unless given, that kit now prints or that is no
# held field; and when the list holds more than <most>, unverified_most unless given. The verbs' outputs are those
# setup_file kept. It fails when it prints a line.
held-unprinted() {
  local found
  found=$(jq --raw-output --slurpfile outputs "${world}/outputs.json" --argjson unverified "${2:-${unverified}}" \
    --argjson most "${3:-${unverified_most}}" "${model_jq}"'
    $outputs[0] as $out
    | [held[] | . as $f | ($f.readby | verb) as $verb | ($f.readby | key) as $key | $out[$verb] as $o
       | ($o.line // [] | join(" ")) as $line
       | if $key == "*" then "\($f.member) has read-by \($f.readby), whose key, * alone, names no key"
         elif $o == null then "\($f.member) names kit \($verb), which setup_file did not run"
         elif $o.status != 0 then "\($f.member): kit \($line) failed with \($o.status): \($o.stderr)"
         elif $o.doc == null then "\($f.member): kit \($line) printed no JSON"
         else
           [$o.doc | rows | at($key | split("."))] as $values
           | if $unverified[$f.member] != null then
               (if ($values | map(select(. != null)) | length) > 0
                then "\($f.member) is unverified, and kit \($line) prints \($key): take it off the list" else empty end)
             elif ($values | length) == 0 then "\($f.member): kit \($line) prints no \($key) in any row"
             elif ($values | all(. == null)) then "\($f.member): kit \($line) prints \($key) only as null, in every row"
             else empty end
         end]
    + [($unverified | keys[]) as $m | select([held[].member] | index($m) | not)
       | "\($m) is unverified, but it is not a held field: take it off the list"]
    + (if ($unverified | length) > $most
       then ["the unverified list holds \($unverified | length) fields, more than the \($most) it may"] else [] end)
    | unique[]' "$1")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

# verbs-unknown <model> prints a line for each held field whose read-by names a verb kit does not have, or words the
# verb does not take, as kit syntax <verb> --match judges them with each option given its value, and fails when it
# prints one. A word after the verb that is not an option must be a literal of the verb's grammar, a stage or a
# subcommand, never an operand, and an option is written without a value, as model.schema.json's read-by pattern also
# holds. Each verb's words are judged once, however many fields name them.
verbs-unknown() {
  local model=$1 verbs verb verdict judged='{}' found
  local -a words line
  verbs=$("${kit_root}/bin/kit" syntax --list | cut -f 1)
  while IFS= read -r verb
  do
    read -r -a words <<<"${verb}"
    if [[ "${verb}" == *=* ]]
    then
      verdict="which gives an option a value, and a read-by writes an option without one, as --show"
    elif ! grep --quiet --line-regexp --fixed-strings -- "${words[0]}" <<<"${verbs}"
    then
      verdict="whose verb ${words[0]} kit does not have"
    else
      mapfile -t line < <(option-values "${words[@]:1}")
      verdict=$("${kit_root}/bin/kit" syntax "${words[0]}" --match -- "${line[@]}" \
        | jq --raw-output --argjson words "$(json-words "${line[@]}")" --arg verb "${words[0]}" '
          if .status != 0 then "which kit refuses: \(.refusal // .missing)"
          else .literals as $literals
            | [$words[] | select(startswith("--") | not) | select(. as $w | $literals | index($w) | not)]
            | if . == [] then "" else "whose \(join(" ")) is not a stage or subcommand of kit \($verb)" end
          end')
    fi
    judged=$(jq --arg verb "${verb}" --arg verdict "${verdict}" '.[$verb] = $verdict' <<<"${judged}")
  done < <(jq --raw-output "${model_jq}"' [held[].readby | verb] | unique[]' "${model}")
  found=$(jq --raw-output --argjson judged "${judged}" "${model_jq}"'
    held[] | $judged[.readby | verb] as $verdict | select($verdict != "")
    | "\(.member) has read-by \(.readby), \($verdict)"' "${model}")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

# json-words <word>… prints the words as a JSON array.
json-words() {
  (( $# > 0 )) || { printf '[]\n'; return 0; }
  printf '%s\n' "$@" | jq --raw-input --slurp --compact-output 'split("\n")[:-1]'
}

# option-values <word>… prints each word, one a line: an option verb_values names as --option=value, any other word
# as it is.
option-values() {
  local word
  for word in "$@"
  do
    jq --raw-output --arg word "${word}" '.[$word] as $v | if $v == null then $word else "\($word)=\($v)" end' \
      <<<"${verb_values}"
  done
}

# run-verbs <root> runs each verb a held field's read-by names, and each of code_verbs, where verb_places says, with
# the values verb_values gives and with --json where the verb takes it, and writes outputs.json: for each verb's
# words, the command line, its status, what it wrote on stderr, and the JSON it printed, or null.
run-verbs() {
  local root=$1 verb place status out=${1}/out.json err=${1}/err.txt
  local -a words line
  printf '{}\n' > "${root}/outputs.json"
  while IFS= read -r verb
  do
    read -r -a words <<<"${verb}"
    mapfile -t line < <(option-values "${words[@]}")
    if "${kit_root}/bin/kit" syntax "${words[0]}" --match -- "${line[@]:1}" --json | jq --exit-status '.status == 0' \
      >/dev/null
    then
      line+=(--json)
    fi
    place=$(jq --raw-output --arg verb "${verb}" '.[$verb] // "repo"' <<<"${verb_places}")
    status=0
    (cd "${root}/${place}" && "${kit_root}/bin/kit" "${line[@]}") > "${out}" 2> "${err}" || status=$?
    jq --exit-status . "${out}" >/dev/null 2>&1 || printf 'null\n' > "${out}"
    jq --arg verb "${verb}" --argjson status "${status}" --rawfile err "${err}" --slurpfile doc "${out}" \
      --argjson line "$(json-words "${line[@]}")" \
      '.[$verb] = {line: $line, status: $status, stderr: $err, doc: $doc[0]}' \
      < "${root}/outputs.json" > "${root}/outputs.next" || return 1
    mv "${root}/outputs.next" "${root}/outputs.json" || return 1
  done < <(jq --raw-output --argjson code "${code_verbs}" "${model_jq}"'
    [held[].readby | verb] + $code | unique[]' "${root}/model.json")
}

# keys-unclaimed <model> [<allowlist>] prints a line for each top-level key a row of a Code verb prints that no
# read-by of that verb names and the allowlist, code_allowlist unless given, does not hold; for each allowlisted key
# the verb does not print; for each allowlisted key a read-by names; and for each Entity.member a reason names that
# the model holds as neither a relation nor a held field. It fails when it prints a line.
keys-unclaimed() {
  local found
  found=$(jq --raw-output --slurpfile outputs "${world}/outputs.json" --argjson code "${code_verbs}" \
    --argjson allow "${2:-${code_allowlist}}" "${model_jq}"'
    . as $model | $outputs[0] as $out
    | [$code[] as $verb
       | if $out[$verb].doc == null then "kit \($verb) printed no JSON, so no key of its rows is checked"
         else
           ([$out[$verb].doc | rows | objects | keys[]] | unique) as $printed
           | ([$model | held[] | select(.readby | verb == $verb) | .readby | key | split(".")[0]] | unique) as $named
           | ($allow[$verb] // {} | keys) as $allowed
           | (($printed - $named - $allowed)[]
              | "kit \($verb) prints \(.), which no read-by of kit \($verb) names and the allowlist does not hold"),
             (($allowed - $printed)[] | "the allowlist holds \(.) for kit \($verb), which kit \($verb) does not print"),
             (($allowed - ($allowed - $named))[]
              | "the allowlist holds \(.) for kit \($verb), which a read-by of kit \($verb) names")
         end]
    + [($allow | keys[]) as $verb | select($code | index($verb) | not)
       | "the allowlist holds kit \($verb), which is not one of code_verbs"]
    + [$allow | to_entries[] | .key as $verb | .value | to_entries[] | .key as $key
       | .value | scan("[A-Z][A-Za-z]+\\.[a-z][a-z0-9-]*") as $token | ($token | split(".")) as [$entity, $member]
       | select(($model.entities[$entity].relations // {} | has($member))
                or $model.entities[$entity].fields[$member].status == "held" | not)
       | "the allowlist gives \($key) of kit \($verb) for \($token), which is no relation and no held field"]
    | unique[]' "$1")
  [[ -z "${found}" ]] || { printf '%s\n' "${found}"; return 1; }
}

@test "every header of every object in the fixture is a field of its entity" {
  objects-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  reaches "${BATS_TEST_TMPDIR}/seen.tsv" "${object_reach}"
  unnamed "${world}/model.json" "${object_names}" "${BATS_TEST_TMPDIR}/seen.tsv"
}

@test "a header of the fixture's objects the model does not name fails the check, naming the header and the member" {
  objects-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  run unnamed "$(broken-model git/git-commit.yml 'del(.fields["extra-headers"])')" "${object_names}" \
    "${BATS_TEST_TMPDIR}/seen.tsv"
  [ "$status" -eq 1 ]
  [ "$output" = "the commit header x-model-extra is held by GitCommit.extra-headers, but GitCommit has no field, relation, or variant extra-headers" ]
  seen "commit header" change-id "a commit" >> "${BATS_TEST_TMPDIR}/seen.tsv"
  run unnamed "${world}/model.json" "${object_names}" "${BATS_TEST_TMPDIR}/seen.tsv"
  [ "$status" -eq 1 ]
  [ "$output" = "the model names nothing for the commit header change-id, which git wrote at a commit" ]
}

@test "a walk that observes nothing, or loses a case the fixture holds, fails its reach, naming each case" {
  : > "${BATS_TEST_TMPDIR}/none.tsv"
  run reaches "${BATS_TEST_TMPDIR}/none.tsv" "${object_reach}"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq "$(jq length <<<"${object_reach}")" ]
  [[ "$output" == *"the observations hold no commit header mergetag, which the fixture is built to hold"* ]]
  [[ "$output" == *"the observations hold no signature status G, which the fixture is built to hold"* ]]
  for reach in "${config_reach}" "${git_dir_reach}" "${index_reach}"
  do
    run reaches "${BATS_TEST_TMPDIR}/none.tsv" "${reach}"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq "$(jq length <<<"${reach}")" ]
  done
  objects-seen > "${BATS_TEST_TMPDIR}/all.tsv"
  grep -v $'^tree entry mode\t160000\t' "${BATS_TEST_TMPDIR}/all.tsv" > "${BATS_TEST_TMPDIR}/seen.tsv"
  run reaches "${BATS_TEST_TMPDIR}/seen.tsv" "${object_reach}"
  [ "$status" -eq 1 ]
  [ "$output" = "the observations hold no tree entry mode 160000, which the fixture is built to hold" ]
}

@test "a git call that fails, or writes an error, ends the walk that made it, naming the call" {
  run fixture-git repo cat-file commit 0000000000000000000000000000000000000000
  [ "$status" -eq 2 ]
  [[ "$output" == "git -C repo cat-file commit 0000000000000000000000000000000000000000 wrote on stderr, or exited 128:"* ]]
  # %G? in a clone that names no allowed signers file says so on stderr, and exits 0
  git clone --quiet "${world}/conflict" "${BATS_TEST_TMPDIR}/w/signed"
  world=${BATS_TEST_TMPDIR}/w run fixture-git signed log --format='%G?'
  [ "$status" -eq 2 ]
  [[ "$output" == *"wrote on stderr, or exited 0:"*"allowedSignersFile"* ]]
  world=${BATS_TEST_TMPDIR}/no-world
  run objects-seen
  [ "$status" -eq 1 ]
  [[ "$output" == *"git -C repo cat-file --batch-all-objects"*"wrote on stderr, or exited 128:"* ]]
  run config-seen
  [ "$status" -eq 1 ]
  [[ "$output" == *"git -C repo config --list"*"wrote on stderr, or exited 128:"* ]]
  run git-dirs-seen
  [ "$status" -eq 1 ]
  [[ "$output" == *"dir-files-seen: repo/.git is not a directory of the fixture"* ]]
}

@test "a worktree whose .git names a missing directory ends the HEAD walk, naming the worktree, never an observation" {
  mkdir -p "${BATS_TEST_TMPDIR}/w"
  cp -R "${world}/repo" "${world}/conflict" "${world}/worktrees" "${BATS_TEST_TMPDIR}/w/"
  printf 'gitdir: %s\n' "${BATS_TEST_TMPDIR}/missing" > "${BATS_TEST_TMPDIR}/w/worktrees/detached/.git"
  world=${BATS_TEST_TMPDIR}/w run git-dirs-seen
  [ "$status" -eq 1 ]
  [[ "$output" == *"git -C worktrees/detached rev-parse --git-dir wrote on stderr, or exited 128:"* ]]
  [[ "$output" != *$'worktree HEAD\tdetached\tworktrees/detached'* ]]
  world=${BATS_TEST_TMPDIR}/w run heads-seen repo worktrees/detached
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = $'worktree HEAD\tsymbolic\trepo' ]
  [ "${lines[1]}" = "git -C worktrees/detached rev-parse --git-dir wrote on stderr, or exited 128:" ]
  [[ "${lines[2]}" == "fatal: "* ]]
  [ "${#lines[@]}" -eq 3 ]
}

@test "the fixture builder refuses a git older than 2.42, and a machine without ssh-keygen, saying what it needs" {
  mkdir -p "${BATS_TEST_TMPDIR}/old"
  printf '#!/bin/sh\necho "git version 2.41.0"\n' > "${BATS_TEST_TMPDIR}/old/git"
  chmod +x "${BATS_TEST_TMPDIR}/old/git"
  PATH="${BATS_TEST_TMPDIR}/old:${PATH}" run "${BATS_TEST_DIRNAME}/fixtures/model-repo/build" \
    "${BATS_TEST_TMPDIR}/fixture"
  [ "$status" -eq 1 ]
  [ "$output" = "build: needs git 2.42 or later (worktree add --orphan); this is git 2.41.0" ]
  path-without ssh-keygen
  run "${BATS_TEST_DIRNAME}/fixtures/model-repo/build" "${BATS_TEST_TMPDIR}/fixture"
  [ "$status" -eq 1 ]
  [ "$output" = "build: needs ssh-keygen, which signs the fixture's commits and tags, and it is not on PATH" ]
  [ ! -e "${BATS_TEST_TMPDIR}/fixture" ]
}

@test "every key of every config section the fixture sets is a field" {
  config-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  reaches "${BATS_TEST_TMPDIR}/seen.tsv" "${config_reach}"
  catch-all-wrong "${BATS_TEST_TMPDIR}/seen.tsv"
  unnamed "${world}/model.json" "$(config-table)" "${BATS_TEST_TMPDIR}/seen.tsv"
}

@test "a config key the model does not name, or one in no catch-all, fails the check, naming the key" {
  config-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  run unnamed "$(broken-model git-config/git-remote-config.yml 'del(.fields["push-urls"])')" \
    "$(config-table)" \
    "${BATS_TEST_TMPDIR}/seen.tsv"
  [ "$status" -eq 1 ]
  [ "$output" = "the config key remote.*.pushurl is held by GitRemoteConfig.push-urls, but GitRemoteConfig has no field, relation, or variant push-urls" ]
  run unnamed "${world}/model.json" "${config_names}" "${BATS_TEST_TMPDIR}/seen.tsv"
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == "the model names nothing for the config key branch.*.vscode-merge-base, which git wrote at repo: local file:.git/config" ]]
  [[ "${lines[1]}" == "the model names nothing for the config key remote.*.gh-resolved, which git wrote at repo: local file:.git/config" ]]
}

@test "a catch-all entry the fixture no longer sets, or one that hides a key git documents, fails the check" {
  config-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  run catch-all-wrong "${BATS_TEST_TMPDIR}/seen.tsv" "$(jq '. + {"remote.*.nonesuch": ["GitRemoteConfig.other-keys"],
    "core.bare": ["GitDir.bare"]}' <<<"${config_catch_all}")"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "config_catch_all gives core.bare to GitDir.bare, which is no section's other-keys" ]
  [ "${lines[1]}" = "config_catch_all holds core.bare, which config_names maps as a key git documents" ]
  [ "${lines[2]}" = "config_catch_all holds remote.*.nonesuch, which the fixture no longer sets" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "every ref, every file of the fixture's git directories, and every worktree's state is named by the model" {
  git-dirs-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  reaches "${BATS_TEST_TMPDIR}/seen.tsv" "${git_dir_reach}"
  unmodelled-stale "${BATS_TEST_TMPDIR}/seen.tsv"
  git-dir-table > "${BATS_TEST_TMPDIR}/table.json"
  unnamed "${world}/model.json" "$(cat "${BATS_TEST_TMPDIR}/table.json")" "${BATS_TEST_TMPDIR}/seen.tsv"
}

@test "a lock the model does not name fails the check of the git directories, naming the member" {
  git-dirs-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  run unnamed "$(broken-model git-repository/git-worktree-admin.yml 'del(.fields["lock-reason"])')" \
    "$(git-dir-table)" "${BATS_TEST_TMPDIR}/seen.tsv"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "the linked worktree dir file locked is held by GitWorktreeAdmin.lock-reason, but GitWorktreeAdmin has no field, relation, or variant lock-reason" ]
  [ "${lines[1]}" = "the worktree list key locked is held by GitWorktreeAdmin.lock-reason, but GitWorktreeAdmin has no field, relation, or variant lock-reason" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "a file both mapped and on git_dir_unmodelled, or an unmodelled one git no longer writes, fails the check" {
  git-dirs-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  run git-dir-table "$(jq '.["common dir file"]["objects/??"] = ["GitDir.store"]' <<<"${git_dir_names}")" \
    "$(jq '.["common dir file"]["objects/??"] = "the loose objects"' <<<"${git_dir_unmodelled}")"
  [ "$status" -eq 1 ]
  [ "$output" = "the common dir file objects/?? is both mapped in git_dir_names and on git_dir_unmodelled" ]
  run unmodelled-stale "${BATS_TEST_TMPDIR}/seen.tsv" \
    "$(jq '.["common dir file"]["rebase-merge"] = "a rebase under way"' <<<"${git_dir_unmodelled}")"
  [ "$status" -eq 1 ]
  [ "$output" = "git_dir_unmodelled holds the common dir file rebase-merge, which the fixture no longer shows" ]
}

@test "every stage, flag, and extension of the fixture's indexes is a field of its entity" {
  indexes-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  reaches "${BATS_TEST_TMPDIR}/seen.tsv" "${index_reach}"
  unnamed "${world}/model.json" "${index_names}" "${BATS_TEST_TMPDIR}/seen.tsv"
}

@test "an index extension the model does not name fails the check, naming the extension" {
  indexes-seen > "${BATS_TEST_TMPDIR}/seen.tsv"
  run unnamed "$(broken-model git-repository/git-index.yml 'del(.relations["resolve-undo"])')" "${index_names}" \
    "${BATS_TEST_TMPDIR}/seen.tsv"
  [ "$status" -eq 1 ]
  [ "$output" = "the index extension REUC is held by GitIndex.resolve-undo, but GitIndex has no field, relation, or variant resolve-undo" ]
}

@test "every held field's read-by names a verb that prints the key" {
  held-unprinted "${world}/model.json"
}

@test "a read-by whose verb does not print its key, or prints it only as null, or names no key, fails the check" {
  run held-unprinted "$(broken-model git-config/git-remote-config.yml \
    '.fields["push-url"]["read-by"] = "workspace remotes pushes"')"
  [ "$status" -eq 1 ]
  [ "$output" = "GitRemoteConfig.push-url: kit workspace remotes --json prints no pushes in any row" ]
  run held-unprinted "$(broken-model code/worktree.yml \
    '.fields.branch["read-by"] = "workspace worktrees links.worktree"')"
  [ "$status" -eq 1 ]
  [ "$output" = "Worktree.branch: kit workspace worktrees --json prints no links.worktree in any row" ]
  run held-unprinted "$(broken-model code/repository.yml '.fields.path["read-by"] = "workspace repos error"')"
  [ "$status" -eq 1 ]
  [ "$output" = "Repository.path: kit workspace repos --json prints error only as null, in every row" ]
  run held-unprinted "$(broken-model code/repository.yml '.fields.path["read-by"] = "workspace repos *"')"
  [ "$status" -eq 1 ]
  [ "$output" = "Repository.path has read-by workspace repos *, whose key, * alone, names no key" ]
}

@test "an unverified field kit prints, one that is no held field, and a list past its most fail the check" {
  run held-unprinted "${world}/model.json" '{"Remote.url": "printed", "Nobody.thing": "gone"}' 1
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Nobody.thing is unverified, but it is not a held field: take it off the list" ]
  [ "${lines[1]}" = "Remote.url is unverified, and kit workspace remotes --json prints url: take it off the list" ]
  [ "${lines[2]}" = "the unverified list holds 2 fields, more than the 1 it may" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "no held field names a verb that does not exist" {
  verbs-unknown "${world}/model.json"
}

@test "a read-by of a verb kit does not have, or of words the verb does not take, fails the check" {
  run verbs-unknown "$(broken-model code/remote.yml '.fields.url["read-by"] = "workspace bogus url"
    | .fields.name["read-by"] = "remotes name" | .fields.forge["read-by"] = "workspaces --nonesuch forge"
    | .fields.primary["read-by"] = "workspaces --show=model kind"')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Remote.url has read-by workspace bogus url, which kit refuses: unknown argument 'bogus'"* ]]
  [[ "$output" == *"Remote.name has read-by remotes name, whose verb remotes kit does not have"* ]]
  [[ "$output" == *"Remote.forge has read-by workspaces --nonesuch forge, which kit refuses: unknown flag '--nonesuch'"* ]]
  [[ "$output" == *"Remote.primary has read-by workspaces --show=model kind, which gives an option a value, and a read-by writes an option without one, as --show"* ]]
  [ "${#lines[@]}" -eq 4 ]
}

@test "every key a row of a Code verb prints is named by a read-by of that verb, or allowlisted with its reason" {
  keys-unclaimed "${world}/model.json"
}

@test "a key no read-by names, an allowlisted key not printed or named, and a reason past its member fail the check" {
  run keys-unclaimed "$(broken-model code/remote.yml \
    'del(.fields.forge["read-by"]) | .fields.forge.status = "planned"')"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "kit workspace remotes prints forge, which no read-by of kit workspace remotes names and the allowlist does not hold" ]
  [ "${lines[1]}" = "the allowlist gives remotes of kit workspace repos for Remote.forge, which is no relation and no held field" ]
  [ "${#lines[@]}" -eq 2 ]
  run keys-unclaimed "${world}/model.json" "$(jq --argjson n '{"nonesuch": "gone", "forge": "named"}' \
    '.["workspace remotes"] += $n | .["workspace nonesuch"] = {"key": "a verb of no Code entity"}' \
    <<<"${code_allowlist}")"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "the allowlist holds forge for kit workspace remotes, which a read-by of kit workspace remotes names" ]
  [ "${lines[1]}" = "the allowlist holds kit workspace nonesuch, which is not one of code_verbs" ]
  [ "${lines[2]}" = "the allowlist holds nonesuch for kit workspace remotes, which kit workspace remotes does not print" ]
  [ "${#lines[@]}" -eq 3 ]
}

# ----------------------------------------------------------------------------------------------------------------------
