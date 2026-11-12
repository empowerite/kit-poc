<!-- kit:generated -- kit welcome's second step, the toolchains, from the kit package -->
<!-- see: "Changing what kit adds" in .kit/1st.md, to replace it -->
# Toolchains — the tools kit runs on, and what installs them

kit runs on four tools: bash, git, jq, and yq. This step checks each one. Then it checks the machine's
[package manager](kittui:welcome/terms/package%20manager), such as brew or apt, which installs them.

When a check fails, the line under it gives the command that fixes it, or says where to read more. Run the command
yourself, or have kit run it and check again. kit runs nothing until you ask, and it never runs a command that has
to run in your own shell.

The tools a repository's work needs are its [toolchain](kittui:welcome/terms/toolchain). Setup, the next step,
checks it in each folder. For how kit finds and chooses what installs the tools, read
[docs/toolchains.md](https://github.com/empowerite/kit/blob/main/docs/toolchains.md).

`kit toolchains`
