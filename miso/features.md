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

- `imp/pseudocode.md` : natural-language definition of new functions, and patching instructions (where in the product they should be called from, or what they should replace)

platform-specific versions of this, eg.
- `imp/ios.md` : actual code for new functions, and patching instructions referring to specific products.

- any other useful artefacts we might want to generate, such as logs, debugging issues, and so on.