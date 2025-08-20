# tools
*computer programs that perform repeatable actions*

*Tools* are conventional programs you can run - from command-line utilities to interactive desktop apps or websites.

Tools are allowed to do anything on your computer, *except* call out to external APIs.

However, they *can* be called by agents.

A tool implementing feature `A/B/C` stores its code and build artefacts in a folder under `A/B/C~/imp/**` where `**` is the name of the platform.