# ui-automation
*remote control of interface buttons for testing*

The `ui-automation` feature allows you to press buttons and interact with the app remotely, without physically tapping the screen. This makes it possible to automate testing and capture screenshots of different app states.

**How it works**: Buttons in the app are given names (like "toolbar-plus"). You can then trigger these buttons from your computer by sending a simple command, and the app responds as if you'd tapped it.

**Why this is useful**: You can script complex interactions - like "press this button, wait a moment, take a screenshot" - all from the command line. This is especially helpful when you want to verify that UI changes look correct, or test multi-step workflows without manual tapping.
