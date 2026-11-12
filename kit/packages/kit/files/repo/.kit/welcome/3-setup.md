<!-- kit:generated -- kit welcome's third step, setup, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Setup — this machine's logins, then each folder of the workspace

This step checks what the work in a repository needs. On this machine, it checks the command-line tool of each
[code forge](kittui:welcome/terms/code%20forge) your repositories use, and your login there. Then it checks each
folder of the [workspace](kittui:welcome/terms/workspace) on its own, the [desk](kittui:welcome/terms/desk) first
and then each [worktree](kittui:welcome/terms/worktree). In a folder, it checks kit and the files it places, the git
hooks, the tools and linters, and `kit check`.

When a check fails, the line under it gives the command that fixes it, or says where to read more. Run the command
yourself, or have kit run it and check again. kit runs nothing until you ask. A folder's fix runs in that folder.

A check drawn 💡 is an offer: it holds, and you can leave it. Outside a repository, with no workspace, only the
machine is checked. For how kit finds the folders, read
[docs/workspaces.md](https://github.com/empowerite/kit/blob/main/docs/workspaces.md).

`kit welcome --checks`
