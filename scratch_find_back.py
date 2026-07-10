import os
import re

lib_dir = r"c:\company\truthworld\lib"
patterns = [
    r"Icons\.arrow_back",
    r"Icons\.chevron_left",
]

matches = []
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
            for idx, line in enumerate(lines):
                for pattern in patterns:
                    if re.search(pattern, line):
                        matches.append((path, idx + 1, line.strip()))

print(f"Found {len(matches)} matches:")
for path, line_no, content in matches:
    print(f"{path}:{line_no}: {content}")
