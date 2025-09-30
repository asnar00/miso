# specifications
*how miso represents program specifications*

`miso` represents programs using *feature modular specifications* : a tree of short natural-language markdown files called "snippets" (like this one).

Every snippet has a unique identifier: `A/B/C` means "subfeature C of subfeature B of feature A".

Snippet `A/B/C` is stored in the file `A/B/C.md`.

Implementation details, including code, notes, change histories, and so on, for snippet `A/B/C` are stored in the folder `A/B/C/imp` (`imp` is a reserved name). Under this folder, runnable code is stored in a subfolder named for the target platform, eg. `ios`, `py`, `android`.