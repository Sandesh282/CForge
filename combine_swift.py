import os

def combine_swift_files(root_dir, output_file="combined_code.txt"):
    """
    Recursively finds all .swift files in the directory tree,
    combines them into a single file with clear markers.
    """
    with open(output_file, "w", encoding="utf-8") as outfile:
        for root, _, files in os.walk(root_dir):
            for file in files:
                if file.endswith(".swift"):
                    file_path = os.path.join(root, file)
                    relative_path = os.path.relpath(file_path, root_dir)
                    
                    # Write header
                    outfile.write(f"\n// MARK: - {relative_path}\n")
                    outfile.write("// " + "=" * 50 + "\n\n")
                    
                    # Write file content
                    try:
                        with open(file_path, "r", encoding="utf-8") as infile:
                            outfile.write(infile.read() + "\n")
                    except UnicodeDecodeError:
                        print(f"Skipped binary file: {file_path}")

if __name__ == "__main__":
    project_root = input("Enter path to CForge project directory: ").strip()
    if not os.path.exists(project_root):
        print("Error: Directory not found!")
    else:
        combine_swift_files(project_root)
        print(f"All Swift files combined into 'combined_code.txt'")
