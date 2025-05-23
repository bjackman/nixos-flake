import json
from pathlib import Path

def get_nixos_revision(file_path_str: str):
    file_path = Path(file_path_str)
    revision = None
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        revision = data.get("configurationRevision")
        if revision is None:
            print(f"Warning: 'configurationRevision' key not found in {file_path_str}")
            
    except FileNotFoundError:
        print(f"Error: File not found at {file_path_str}")
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {file_path_str}")
    except Exception as e:
        print(f"An unexpected error occurred with {file_path_str}: {e}")
        
    return revision

file1_path = "src/falba/testdata/results/nixos-asi-benchmarks:836d59863d4a/artifacts/nixos-version.json"
file2_path = "src/falba/testdata/results/nixos-asi-benchmarks:d6b0e7e4b7b4/artifacts/nixos-version.json"

revision1 = get_nixos_revision(file1_path)
revision2 = get_nixos_revision(file2_path)

# Using a more specific part of the path for brevity in the report
file1_label = "...836d59863d4a/..."
file2_label = "...d6b0e7e4b7b4/..."

if revision1 is not None:
    print(f"File 1 ({file1_label}) configurationRevision: '{revision1}'")
else:
    print(f"File 1 ({file1_label}) configurationRevision: Not found or error processing file.")

if revision2 is not None:
    print(f"File 2 ({file2_label}) configurationRevision: '{revision2}'")
else:
    print(f"File 2 ({file2_label}) configurationRevision: Not found or error processing file.")

