import os

OUTPUT_FILE = "clash_codebase.txt"
# Extensions to include
INCLUDE_EXTS = {".gd", ".tscn", ".tres", ".md"}
# Folders or files to completely skip
IGNORE_DIRS = {".godot", ".git", "Art", "Fonts", ".import"}

with open(OUTPUT_FILE, "w", encoding="utf-8") as outfile:
    # Write directory structure map first
    outfile.write("# PROJECT TREE OVERVIEW\n\n")
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for f in files:
            if any(f.endswith(ext) for ext in INCLUDE_EXTS):
                rel_path = os.path.relpath(os.path.join(root, f), ".")
                outfile.write(f"- {rel_path}\n")

    outfile.write("\n" + "=" * 50 + "\n\n")

    # Append the actual text content of each file
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for f in files:
            if any(f.endswith(ext) for ext in INCLUDE_EXTS):
                filepath = os.path.join(root, f)
                rel_path = os.path.relpath(filepath, ".")
                outfile.write(f"\n--- START FILE: {rel_path} ---\n\n")
                try:
                    with open(filepath, "r", encoding="utf-8", errors="ignore") as infile:
                        outfile.write(infile.read())
                except Exception as e:
                    outfile.write(f"# Could not read file: {e}\n")
                outfile.write(f"\n--- END FILE: {rel_path} ---\n\n")

print(f"Done! Packed cleanly into {OUTPUT_FILE}")