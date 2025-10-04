# features
*modular capabilities that define program behavior*

`miso` specifies programs as a tree of *features* : short (<300 word) natural-language markdown files that specify behaviour.

Features:

- start with a '#' title
- followed by an *emphasized* one-line summary
- up to 300 words or so of natural language
- use simple language understandable by users
- avoid technical jargon and code

To add detail to a feature `A.md`, we create a *subfeature* `A/B.md`; to add detail to `A/B`, we create a subfeature `A/B/C.md`; and so on.

To keep things manageable, a feature should have no more than four or six children. If the number of children gets out of control, they should be grouped and summarised appropriately.

Implementation details for a feature `A/B/C` are stored in the folder `A/B/C/imp`, and should contain:

- natural-language pseudocode describing additional functions, and where they should be called from
- platform-specific code in subfolders eg `imp/py` or `imp/eos`
- any other artefacts like tests, debugging, etc.

