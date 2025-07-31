ᕦ(ツ)ᕤ
# miso

`miso` ("make it so") is a system for laypeople who want to create their own software tools using natural language; but don't want to sacrifice readability, maintainability, robustness or portability.

In `miso`, we represent software as a *feature-modular specification* - short natural language snippets of markdown text, arranged in a tree. The goal is that each snippet summarises its entire functionality and purpose in around 250-300 words, making it quick to understand for humans and agents alike.

When we want to add detail to a feature, we don't edit its snippet; instead, we add a child snippet that summarises the detail.

When instructed, a human-configurable agent works to "make it so" - to implement the specification snippets as they change, refining the spec as we go.
