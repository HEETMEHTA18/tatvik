import os
import sys

replacements = {
    "Tatvik": "Tatvik",
    "tatvik": "tatvik",
    "Tatvik": "Tatvik",
    "TATVIK": "TATVIK"
}

ignore_dirs = ['.git', '.dart_tool', 'build', '__pycache__', 'venv', 'node_modules', '.github']

def replace_in_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        for k, v in replacements.items():
            content = content.replace(k, v)
            
        if original != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {filepath}")
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

def main():
    for root, dirs, files in os.walk('.'):
        # Filter out ignored directories
        dirs[:] = [d for d in dirs if not any(ignore == d or ignore in os.path.join(root, d) for ignore in ignore_dirs)]
        
        for file in files:
            if file.endswith(('.dart', '.py', '.md', '.yaml', '.yml', '.json', '.html', '.txt')):
                replace_in_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
