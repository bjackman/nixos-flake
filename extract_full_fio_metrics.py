import json
from pathlib import Path

def get_full_fio_metrics(file_path_str: str):
    file_path = Path(file_path_str)
    metrics_summary = []
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        for job in data.get("jobs", []):
            job_name = job.get("jobname")
            read_stats = job.get("read", {})
            
            lat_ns_stats = read_stats.get("lat_ns", {})
            read_lat_ns_mean = lat_ns_stats.get("mean")
            
            slat_ns_stats = read_stats.get("slat_ns", {})
            read_slat_ns_mean = slat_ns_stats.get("mean")
            
            clat_ns_stats = read_stats.get("clat_ns", {})
            read_clat_ns_mean = clat_ns_stats.get("mean")
            
            read_iops = read_stats.get("iops")
            
            if job_name is not None and read_lat_ns_mean is not None and                read_slat_ns_mean is not None and read_clat_ns_mean is not None and                read_iops is not None:
                metrics_summary.append({
                    "jobname": job_name,
                    "lat_ns_mean": read_lat_ns_mean,
                    "slat_ns_mean": read_slat_ns_mean,
                    "clat_ns_mean": read_clat_ns_mean,
                    "iops": read_iops
                })
            else:
                print(f"Warning: Missing some metric data for job '{job_name}' in {file_path_str}")

    except FileNotFoundError:
        print(f"Error: File not found at {file_path_str}")
        return []
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {file_path_str}")
        return []
    except Exception as e:
        print(f"An unexpected error occurred with {file_path_str}: {e}")
        return []
        
    return metrics_summary

# Using relative paths as they are in the test file, assuming script is run from /app
testdata_dir_in_script = Path("src/falba/testdata")

file1_path = testdata_dir_in_script / "results/nixos-asi-benchmarks:836d59863d4a/artifacts/fio_output.json"
file2_path = testdata_dir_in_script / "results/nixos-asi-benchmarks:d6b0e7e4b7b4/artifacts/fio_output.json"

metrics1 = get_full_fio_metrics(str(file1_path))
metrics2 = get_full_fio_metrics(str(file2_path))

file1_label = "...836d59863d4a/..."
file2_label = "...d6b0e7e4b7b4/..."

print(f"File 1 ({file1_label}) full metrics: {metrics1}")
print(f"File 2 ({file2_label}) full metrics: {metrics2}")

