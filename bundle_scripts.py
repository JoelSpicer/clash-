import os

# --- CONFIGURATION ---
# Add or remove extensions you want to see in the list
VALID_EXTENSIONS = {'.gd', '.gdshader', '.tscn'}
OUTPUT_FILE = "ProjectDump.txt"
# Folders to completely ignore
IGNORE_FOLDERS = {'.godot', '.git', 'addons'} 

def get_project_files():
    file_list = []
    for root, dirs, files in os.walk("."):
        # Remove ignored folders from search
        dirs[:] = [d for d in dirs if d not in IGNORE_FOLDERS]
        
        for file in files:
            if any(file.endswith(ext) for ext in VALID_EXTENSIONS):
                if file != OUTPUT_FILE and file != os.path.basename(__file__):
                    file_list.append(os.path.join(root, file))
    return sorted(file_list)

def main():
    print("--- Godot Project Bundler ---")
    files = get_project_files()
    
    if not files:
        print("No matching files found!")
        return

    # 1. Show the list
    for i, file_path in enumerate(files):
        print(f"[{i}] {file_path}")

    print("\nInstructions:")
    print("- Enter numbers separated by commas (e.g., 1, 4, 12)")
    print("- Enter a range (e.g., 5-10)")
    print("- Type 'all' to select everything")
    
    selection = input("\nWhich files do you want to bundle? ").strip().lower()

    selected_indices = set()

    # 2. Parse Selection
    if selection == 'all':
        selected_indices = set(range(len(files)))
    else:
        parts = selection.split(',')
        for part in parts:
            part = part.strip()
            if '-' in part:
                try:
                    start, end = map(int, part.split('-'))
                    selected_indices.update(range(start, end + 1))
                except: pass
            else:
                try:
                    selected_indices.add(int(part))
                except: pass

    # 3. Compile the File
    if not selected_indices:
        print("No valid files selected. Exiting.")
        return

    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        out.write(f"--- PROJECT BUNDLE ---\n\n")
        for idx in sorted(selected_indices):
            if idx < len(files):
                file_path = files[idx]
                print(f"Adding: {file_path}")
                out.write(f"\n{'='*60}\n")
                out.write(f"FILE: {file_path}\n")
                out.write(f"{'='*60}\n")
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        out.write(f.read())
                except Exception as e:
                    out.write(f"[ERROR READING FILE: {e}]")
                out.write("\n")

    print(f"\nSuccess! {len(selected_indices)} files compiled into {OUTPUT_FILE}")

if __name__ == "__main__":
    main()