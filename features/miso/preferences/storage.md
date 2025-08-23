# storage
*where snippets are stored*

A snippet `A/B/C` ("subfeature C of subfeature B of feature A") are stored in the file `features/A/B/C.md`.

Meta-information about a snippet (eg. running code, conversations, plans, build artefacts) are stored in the snippet's *meta-folder* `A/B/C/meta`.

When a snippet defines an object, we can store a list of instances of that object in `A/B/C/all/`.

Tool implementations go into `A/B/C/meta/code/xxx/` where xxx is the implementation name (eg. `py`).
