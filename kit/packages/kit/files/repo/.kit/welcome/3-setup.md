<!-- kit:generated -- kit welcome's third step, setup, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Setup — this machine's logins and terminal

`kit welcome --checks --machine`

This step checks what the work on this machine needs. It checks the command-line tool of the
[code forge](kittui:welcome/terms/code%20forge) kit reaches, GitHub's `gh`, and your login there. In a terminal, it
also judges the terminal kit runs in, and names each of its settings that makes kittui slower or worse.

When a check fails, the line under it gives the command that fixes it, or says where to read more. Run the command
yourself, or have kit run it and check again. kit runs nothing until you ask. A terminal's fixes are yours to make in
its settings, so kit shows them and never runs them, and `keep` holds a finding as it is.

A check drawn 💡 is an offer: it holds, and you can leave it. This guide checks the machine alone, and knows no
repository or workspace. Inside a repository, `kit welcome --text` also checks each folder of its workspace: kit
installed, its files placed, the git hooks, the tools and linters, and `kit check`. For how kit finds the folders,
read [docs/workspaces.md](https://github.com/empowerite/kit/blob/main/docs/workspaces.md).
