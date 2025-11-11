#!/usr/bin/env python3
"""
Add a Swift file to an Xcode project by editing project.pbxproj.

Usage:
    python3 add-file-to-project.py <project.xcodeproj> <file.swift>

Example:
    python3 add-file-to-project.py NoobTest.xcodeproj NoobTest/FloatingSearchBar.swift
"""

import sys
import os
import uuid
import re

def generate_uuid():
    """Generate a UUID in Xcode format (lowercase, no hyphens)"""
    return uuid.uuid4().hex.upper()[:24]

def read_file(filepath):
    """Read file contents"""
    with open(filepath, 'r') as f:
        return f.read()

def write_file(filepath, content):
    """Write file contents"""
    with open(filepath, 'w') as f:
        f.write(content)

def add_file_to_project(project_path, file_path):
    """Add a Swift file to an Xcode project"""

    # Validate inputs
    if not project_path.endswith('.xcodeproj'):
        print(f"Error: {project_path} is not an .xcodeproj directory")
        return False

    if not os.path.exists(file_path):
        print(f"Error: {file_path} does not exist")
        return False

    pbxproj_path = os.path.join(project_path, 'project.pbxproj')
    if not os.path.exists(pbxproj_path):
        print(f"Error: {pbxproj_path} not found")
        return False

    # Get filename
    filename = os.path.basename(file_path)

    # Generate UUIDs
    build_uuid = generate_uuid()
    file_uuid = generate_uuid()

    print(f"Adding {filename} to {project_path}")
    print(f"  BUILD_UUID: {build_uuid}")
    print(f"  FILE_UUID:  {file_uuid}")

    # Read project file
    content = read_file(pbxproj_path)

    # Backup
    backup_path = pbxproj_path + '.backup'
    write_file(backup_path, content)
    print(f"  Backup: {backup_path}")

    # 1. Add to PBXBuildFile section
    pbx_build_file = f"\t\t{build_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};\n"
    content = content.replace(
        '/* Begin PBXBuildFile section */',
        '/* Begin PBXBuildFile section */\n' + pbx_build_file
    )

    # 2. Add to PBXFileReference section
    pbx_file_reference = f"\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    content = content.replace(
        '/* Begin PBXFileReference section */',
        '/* Begin PBXFileReference section */\n' + pbx_file_reference
    )

    # 3. Add to PBXGroup section (find main group and add to children)
    # Look for the first PBXGroup with children array
    group_pattern = r'(\/\* Begin PBXGroup section \*\/.*?children = \()(.*?)(\);)'
    match = re.search(group_pattern, content, re.DOTALL)
    if match:
        children_content = match.group(2)
        new_child = f"\n\t\t\t\t{file_uuid} /* {filename} */,"
        new_children = children_content + new_child
        content = content.replace(match.group(0), match.group(1) + new_children + match.group(3))
    else:
        print("Warning: Could not find PBXGroup children array")

    # 4. Add to PBXSourcesBuildPhase section (find files array)
    sources_pattern = r'(\/\* Sources \*\/ = \{.*?files = \()(.*?)(\);)'
    match = re.search(sources_pattern, content, re.DOTALL)
    if match:
        files_content = match.group(2)
        new_file = f"\n\t\t\t\t{build_uuid} /* {filename} in Sources */,"
        new_files = files_content + new_file
        content = content.replace(match.group(0), match.group(1) + new_files + match.group(3))
    else:
        print("Warning: Could not find PBXSourcesBuildPhase files array")

    # Write updated project file
    write_file(pbxproj_path, content)
    print(f"✅ Successfully added {filename} to project")
    print(f"   To verify: xcodebuild -project {project_path} -scheme <scheme> build")

    return True

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 add-file-to-project.py <project.xcodeproj> <file.swift>")
        print("Example: python3 add-file-to-project.py NoobTest.xcodeproj NoobTest/FloatingSearchBar.swift")
        sys.exit(1)

    project_path = sys.argv[1]
    file_path = sys.argv[2]

    success = add_file_to_project(project_path, file_path)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
