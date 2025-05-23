import json
from pathlib import Path

def get_fio_metrics(file_path_str: str):
    file_path = Path(file_path_str)
    metrics = []
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        for job in data.get("jobs", []):
            job_name = job.get("jobname")
            
            read_stats = job.get("read", {})
            read_iops = read_stats.get("iops")
            
            clat_ns = read_stats.get("clat_ns", {})
            read_clat_ns_mean = clat_ns.get("mean")
            
            if job_name is not None and read_iops is not None and read_clat_ns_mean is not None:
                metrics.append({
                    "jobname": job_name,
                    "iops": read_iops,
                    "clat_ns_mean": read_clat_ns_mean
                })
            else:
                # Handle cases where some keys might be missing, if necessary
                print(f"Warning: Missing data for a job in {file_path_str}")

    except FileNotFoundError:
        print(f"Error: File not found at {file_path_str}")
        return []
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {file_path_str}")
        return []
    except Exception as e:
        print(f"An unexpected error occurred with {file_path_str}: {e}")
        return []
        
    return metrics

file1_path = "src/falba/testdata/results/nixos-asi-benchmarks:836d59863d4a/artifacts/fio_output.json"
file2_path = "src/falba/testdata/results/nixos-asi-benchmarks:d6b0e7e4b7b4/artifacts/fio_output.json"

metrics1 = get_fio_metrics(file1_path)
metrics2 = get_fio_metrics(file2_path)

# Using a more specific part of the path for brevity in the report, as requested
file1_label = "...836d59863d4a/..."
file2_label = "...d6b0e7e4b7b4/..."

print(f"File 1 ({file1_label}) metrics: {metrics1}")
print(f"File 2 ({file2_label}) metrics: {metrics2}")

