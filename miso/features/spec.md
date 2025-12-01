# features
*modular capabilities that define program behavior*

`miso` specifies programs as a tree of *features*: short (<300 word) natural-language markdown files that specify behaviour.

Features:

- start with a '#' title
- followed by an *emphasized* one-line summary
- up to 300 words or so of natural language
- use simple language understandable by users
- avoid technical jargon and code

## Structure

Each feature lives in its own folder. For a feature called `foo`:

```
foo/
├── spec.md           # the feature specification
├── pseudocode.md     # natural-language function definitions and patching instructions
├── ios.md            # iOS platform implementation
├── eos.md            # Android/e/OS platform implementation
├── py.md             # Python platform implementation
└── imp/              # other artifacts (logs, test files, debugging notes)
```

To add detail to feature `A`, create a subfeature folder `A/B/` containing `B/spec.md`. Subfeatures can nest arbitrarily: `A/B/C/spec.md`, and so on.

To keep things manageable, a feature should have no more than four to six children. If children get out of control, group and summarise them appropriately.

## Files

- `spec.md`: The feature specification in plain language for users
- `pseudocode.md`: Natural-language definition of functions, plus patching instructions (where in the product they should be called, or what they replace)
- `ios.md`, `eos.md`, `py.md`: Platform-specific implementations with actual code
- `imp/`: Folder for other artifacts (logs, debugging issues, test data, etc.)

All executable code lives in the `product/` folder, separate from feature specifications.