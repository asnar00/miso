# bye
*save agent conversation for future reference*

The `bye` tool saves the current agent terminal (Claude Code, for now) into a file `chat/chat-xxx.md` where `xxx` increases monotonically. This should be invoked at the end of a session, before changes are committed to github; this ensures that all chat context for each change is visible.