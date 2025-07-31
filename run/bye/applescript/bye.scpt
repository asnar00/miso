-- bye: save agent conversation for future reference

-- Get the frontmost application name for targeting
tell application "System Events"
	set frontApp to name of first application process whose frontmost is true
end tell

-- Create chat directory if needed
set chatDir to (path to desktop as string) & "experiments:miso:chat:"
tell application "Finder"
	if not (exists folder chatDir) then
		make new folder at (path to desktop as string) & "experiments:miso:" with properties {name:"chat"}
	end if
end tell

-- Find next chat number
set maxNum to 0
tell application "Finder"
	try
		set chatFiles to (files of folder chatDir whose name contains "chat-" and name extension is "md")
		repeat with chatFile in chatFiles
			set fileName to name of chatFile
			try
				set numStr to text 6 thru 8 of fileName -- extract "XXX" from "chat-XXX.md"
				set num to (numStr as integer)
				if num > maxNum then set maxNum to num
			end try
		end repeat
	end try
end tell

set nextNum to maxNum + 1
set paddedNum to text -3 thru -1 of ("000" & nextNum)
set newFileName to "chat-" & paddedNum & ".md"

-- Capture content from frontmost application
tell application "System Events"
	tell application process frontApp
		set frontmost to true
		delay 0.2 -- Brief pause to ensure focus
		keystroke "a" using command down -- Select all
		delay 0.5 -- Wait for selection
		keystroke "c" using command down -- Copy
		delay 0.5 -- Wait for copy to complete
		key code 125 -- Down arrow to clear selection
	end tell
end tell

-- Save to file
set newFilePath to chatDir & newFileName
try
	set chatContent to (the clipboard as string)
	set fileRef to open for access file newFilePath with write permission
	write chatContent to fileRef
	close access fileRef
	display notification "Saved to " & newFileName with title "bye"
	return "Chat saved to " & newFileName
on error errMsg
	try
		close access file newFilePath
	end try
	display notification "Error: " & errMsg with title "bye"
	return "Error saving chat: " & errMsg
end try