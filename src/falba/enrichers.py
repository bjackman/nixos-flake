from collections.abc import Sequence
import sys
if sys.version_info >= (3, 11):
    from typing import Self
else:
    from typing_extensions import Self
from typing import Dict, List, Any, Optional, Callable, Tuple
import json
from fnmatch import fnmatch
import tarfile
import os
import re
import shlex
import datetime

from . import model

class EnrichmentFailure(Exception):
  pass

# Enrichers return (facts, metrics) pairs.

def enrich_from_ansible(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if artifact.path.name != "ansible_facts.json":
    return [], []
  try:
    ansible_facts = json.loads(artifact.content())
  except json.decoder.JSONDecodeError as e:
    raise EnrichmentFailure() from e

  facts = []
  try:
    # Ansible doesn't give us the raw commandline
    facts.append(model.Metric(name="cmdline_fields", value=ansible_facts["ansible_cmdline"]))
    facts.append(model.Metric(name="nproc", value=ansible_facts["ansible_processor_nproc"]))
    facts.append(model.Metric(name="memory", value=ansible_facts["ansible_memtotal_mb"], unit="MB")) # Units are captured for memory
    ansible_ansible_facts = ansible_facts["ansible_facts"] # wat
    facts.append(model.Metric(name="kernel_version", value=ansible_ansible_facts["kernel"]))

    ts = ansible_facts["ansible_date_time"]["iso8601_micro"]
    facts.append(model.Metric(name="timestamp", value=datetime.datetime.fromisoformat(ts)))

    # ansible_processor seems to be a list where each consecutive 3 pairs is
    # (processor number, vendor, model)
    ansible_processor = ansible_facts["ansible_processor"]
  except KeyError as e:
    raise EnrichmentFailure("missing field in ansible all_facts") from e

  try:
    p = ansible_processor
    cpu_models = {int(p[i]): (p[i+1] + " " + p[i+2]) for i in range(0, len(p), 3)}
    facts.append(model.Metric(name="cpu", value=" + ".join(set(cpu_models.values()))))

  except Exception as e:
    raise EnrichmentFailure("failed to parse ansible_processor mess") from e

  # TODO: Need to figure out how to encode my knowledge about whose cmdline this is and ideally where it came from.
  #       Probably when I write the results to the database I should be dropping some metadata
  #       saying that this is an ansible fact dump and how it relates to the SUT.
  return (facts, [])

def enrich_from_phoronix_json(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path, "**/pts-results.json"):
    return {}, []
  try:
    obj = json.loads(artifact.content())
  except json.decoder.JSONDecodeError as e:
    raise EnrichmentFailure() from e
  metrics = []

  try:
    for result in obj["results"].values():
      if result["identifier"] != "pts/fio-2.1.0":
        # This print statement is a side effect during normal operation, consider logging instead if needed.
        # For now, keeping as it might be intentionally verbose for unknown identifiers.
        print(f"Ignoring unknown Phoronix result with identifier: {result['identifier']}")
        continue
      # TODO: do we want some general capability for hierarchical results? For now
      # we'll just store metrics directly as items in the result and then flatten
      # this later into a DF or whatever that's easy to do analysis on.
      for subresult in result["results"].values():
        for value in subresult["raw_values"]:
          args = result["arguments"]
          scale = result["scale"]
          metrics.append(model.Metric(name=f"PTS FIO [{args}] {scale}",
                                value=value,
                                unit=result["scale"]))
  except KeyError as e:
    raise EnrichmentFailure("missing expected field in phoronix-test-suite-result.json") from e
  return {}, metrics

def enrich_from_sysfs_tgz(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path, "*/tmp/sysfs_cpu.tgz"):
    return {}, []
  try:
    facts = []
    with tarfile.open(artifact.path, 'r:gz') as tar:
        for member in tar.getmembers():
            if not fnmatch(member.name, "/sys/devices/system/cpu/vulnerabilities/*"):
              continue
            content = tar.extractfile(member).read().decode('utf-8')
            # tar is too clever and gets confused by sysfs files, strip of the NULs it adds
            facts.append(model.Metric(name=f"sysfs_cpu_vuln:{os.path.basename(member.name)}", value=content.strip('\0').strip()))
    return facts, []
  except Exception as e:
    raise EnrichmentFailure() from e

# TODO: Should each kconfig actually be a separate fact? Maybe facts shoudl inherently be nesting...
def enrich_from_kconfig(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path, "*/kconfig"):
    return {}, []
  kconfig_dict = {}
  for line in artifact.content().decode().splitlines():
    if not line.strip() or line.startswith("#"):
      continue
    try:
      k, v = line.split("=", maxsplit=1)
      kconfig_dict[k] = v
    except Exception as e:
      raise EnrichmentFailure(f"failed to parse kconfig line: {line}") from e
  return [model.Metric(name="kconfig", value=kconfig_dict)], []

# Reads VARIANT_ID from an /etc/os-release file.
def enrich_from_os_release(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path.name, "etc_os-release"): # Corrected to use artifact.path.name
    return [], []

  fields = {}
  for line in artifact.content().decode().splitlines():
    if not line.strip() or line.startswith("#"):
      continue
    k, v = line.split("=", maxsplit=1)
    parts = shlex.split(v)
    if len(parts) != 1:
      raise EnrichmentFailure(f"Seems like an invalid /etc/os-release line (shlex found: {parts}): line")
    fields[k] = parts[0].strip()

  facts, metrics = [], []
  if "VARIANT_ID" in fields:
    facts.append(model.Fact(name="os_release_variant_id", value=fields["VARIANT_ID"]))

  return facts, metrics

# TODO: make the JSON-reading enrichers less boilerplatey

# Reads selected metrics from the output of the FIO benchmark (typically --output-format=json+).
def enrich_from_fio_json_plus(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path.name, "fio_output.json"): # Corrected to use artifact.path.name and simpler pattern
    return [], []

  try:
    output_obj = json.loads(artifact.content())
  except json.decoder.JSONDecodeError as e:
    raise EnrichmentFailure() from e

  facts, metrics = [], []

  try:
    for job in output_obj["jobs"]:
      job_name = job['jobname']
      read_stats = job.get("read", {}) # Use .get for safety

      for fio_metric_type in ["lat_ns", "slat_ns", "clat_ns"]:
        metric_stats = read_stats.get(fio_metric_type, {})
        mean_value = metric_stats.get("mean")
        if mean_value is not None:
            metrics.append(model.Metric(name=f"fio_{job_name}_read_{fio_metric_type}_mean",
                                        value=mean_value))

      iops_value = read_stats.get("iops")
      if iops_value is not None:
          metrics.append(model.Metric(name=f"fio_{job_name}_read_iops",
                                      value=iops_value))
  except KeyError as e:
    raise EnrichmentFailure("missing field in FIO output JSON") from e

  return facts, metrics

# Reads output of `nixos-version --json`
def enrich_from_nixos_version_json(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path, "*/nixos-version.json"):
    return {}, []

  try:
    obj = json.loads(artifact.content())
  except json.decoder.JSONDecodeError as e:
    raise EnrichmentFailure() from e

  facts, metrics = [], []

  try:
    facts.append(model.Fact(name="nixos_configuration_revision", value=obj["configurationRevision"]))
  except KeyError as e:
    raise EnrichmentFailure("missing field in FIO output JSON") from e

  return facts, metrics

# Parses results of bpftrace programs, specifically for 'asi_exits'.
def enrich_from_bpftrace_logs(artifact: model.Artifact) -> Tuple[Sequence[model.Fact], Sequence[model.Metric]]:
  if not fnmatch(artifact.path.name, "bpftrace_asi_exits.log"): # Corrected to use artifact.path.name and simpler pattern
    return [], []

  facts, metrics = [], []

  exits_metric = None
  pattern = r"@total_exits:\s+(\d+)"
  for line in artifact.content().decode().splitlines():
    match = re.search(pattern, line)
    if match:
      if exits_metric:
        logging.warn(f"Found two @total_exits results in {artifact.path}")
      exits_metric = model.Metric(name="asi_exits", value=int(match.group(1)))
  if exits_metric:
    metrics.append(exits_metric)
    facts.append(model.Fact(name="instrumented", value=True))

  return facts, metrics

ENRICHERS = [
    enrich_from_ansible, enrich_from_phoronix_json, enrich_from_sysfs_tgz,
    enrich_from_kconfig, enrich_from_os_release, enrich_from_fio_json_plus,
    enrich_from_nixos_version_json, enrich_from_bpftrace_logs,
]
