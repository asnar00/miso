#!/usr/bin/env python3
import re
import uuid

# Read the project file
project_file = "NoobTest.xcodeproj/project.pbxproj"
with open(project_file, 'r') as f:
    content = f.read()

# Files to add
files_to_add = [
    "SignInView.swift",
    "NewUserView.swift",
    "Post.swift",
    "PostsView.swift",
    "NewPostView.swift"
]

# Generate unique IDs for each file (2 per file: build file and file reference)
def generate_id():
    return uuid.uuid4().hex[:24].upper()

# Create entries for each file
build_file_entries = []
file_ref_entries = []
group_entries = []
sources_entries = []

for filename in files_to_add:
    build_file_id = generate_id()
    file_ref_id = generate_id()

    build_file_entries.append(f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};")
    file_ref_entries.append(f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    group_entries.append(f"\t\t\t\t{file_ref_id} /* {filename} */,")
    sources_entries.append(f"\t\t\t\t{build_file_id} /* {filename} in Sources */,")

# Add to PBXBuildFile section (after line 15)
pbx_build_section = "/* Begin PBXBuildFile section */"
pbx_build_end = "/* End PBXBuildFile section */"
build_section_start = content.find(pbx_build_section)
build_section_end = content.find(pbx_build_end)

# Insert new build file entries before the end marker
new_content = content[:build_section_end] + "\n".join(build_file_entries) + "\n" + content[build_section_end:]

# Add to PBXFileReference section (after line 26)
pbx_file_section = "/* Begin PBXFileReference section */"
pbx_file_end = "/* End PBXFileReference section */"
file_section_start = new_content.find(pbx_file_section)
file_section_end = new_content.find(pbx_file_end)

new_content = new_content[:file_section_end] + "\n".join(file_ref_entries) + "\n" + new_content[file_section_end:]

# Add to PBXGroup section (after Storage.swift line)
# Find the NoobTest group and add after Storage.swift
storage_line = "\t\t\t\t9E92472BFE1E48C68BEE5FB1712CF00E /* Storage.swift */,"
storage_pos = new_content.find(storage_line)
if storage_pos != -1:
    # Find the end of this line
    line_end = new_content.find('\n', storage_pos)
    new_content = new_content[:line_end+1] + "\n".join(group_entries) + "\n" + new_content[line_end+1:]

# Add to PBXSourcesBuildPhase section (after Storage.swift in Sources)
sources_storage_line = "\t\t\t\t223D4D54FDFC4EABA555C8B6F55F6F1C /* Storage.swift in Sources */,"
sources_pos = new_content.find(sources_storage_line)
if sources_pos != -1:
    # Find the end of this line
    line_end = new_content.find('\n', sources_pos)
    new_content = new_content[:line_end+1] + "\n".join(sources_entries) + "\n" + new_content[line_end+1:]

# Write the updated file
with open(project_file, 'w') as f:
    f.write(new_content)

print("✓ Added all missing Swift files to project.pbxproj")
print("Files added:")
for f in files_to_add:
    print(f"  - {f}")
