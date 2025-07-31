# bye pseudocode

- find the frontmost application (Claude Code or Terminal)
- select all content using Cmd-A
- wait briefly for selection to complete
- copy to clipboard using Cmd-C  
- wait for copy operation to complete
- create `chat/` directory if it doesn't exist
- scan existing `chat/chat-*.md` files to find highest number
- increment to get next chat number (e.g., if `chat-003.md` exists, use `004`)
- create new file `chat/chat-XXX.md` with incremented number
- write clipboard contents to the file
- clear selection with down arrow key
- report success with saved filename