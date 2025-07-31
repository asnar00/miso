# tools
*small programs you can run*

A `tool` is a program that the user can invoke from the command line, either by running a script or executable, or by using natural language in an agent terminal.

Tool specifications live in the folder `spec/miso/tools/`.

Runnable code for tool `hello` lives in the folder `run/hello/`.

## pseudocode

Every tool has a single file called `pseudocode.md` which consists of precise, step-by-step instructions that an agent should follow precisely when the tool is invoked. It's fine for a tool to be expressed purely as pseudocode, but it can also be compiled down to ordinary code in any language.

## code

For each implementation, `run/hello/` should contain a folder named after the language or platform of the implementation; eg.

`run/hello/py/` would contain the python code;
`run/hello/sh/` would contain the shell-script code;
`run/hello/cpp` would contain the C+ code;

and so on.
