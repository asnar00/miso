# tools
*executable code*

`tools` are pieces of executable code (command-line utilities, python programs, client/server apps, or native apps) that can be invoked by users or agents to perform repeatable, efficient work.

Tools can call agents, but are always code-first.

Tools live in the code/ folder; a tool implementing feature `A/B/C` will be stored in `code/A/B/C`.

Each tool is described by a natural-language document `pseudocode.md` (in the tool's root folder) that can be run by an agent, by following its instructions precisely.

A tool can contain multiple code implementations; these are stored in subfolders of the tool's code folder, eg. `code/A/B/C/py` or `code/A/B/C/sh`. 