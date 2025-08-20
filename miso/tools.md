# tools
*computer programs that perform repeatable actions*

*Tools* are conventional programs you can run - from command-line utilities to interactive desktop apps or websites.

Tools are allowed to do anything on your computer, *except* call out to external APIs.

However, they *can* be called by agents.

A tool implementing code for platform `X` should store the code in the tool's metafolder, under the `imp/X/` subfolder.