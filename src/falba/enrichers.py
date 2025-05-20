from collections.abc import Sequence
from typing import Dict, List, Self, Any, Optional, Callable, Tuple
import json
from fnmatch import fnmatch
import tarfile
import os
import datetime

#
# Here are some super hacky examples of things that might become fact/metric extraction plugins
#

class EnrichmentFailure(Exception):
  pass

# Enrichers return (facts, metrics) pairs.

def enrich_from_ansible(artifact: Artifact) -> Tuple[Sequence[Fact], Sequence[Metric]]:
  if artifact.path.name != "ansible_facts.json":
    return [], []
  try:
    ansible_facts = json.loads(artifact.content())
  except json.decoder.JSONDecodeError as e:
    raise EnrichmentFailure() from e

  facts = []
  try:
    # Ansible doesn't give us the raw commandline
    facts.append(Metric(name="cmdline_fields", value=ansible_facts["ansible_cmdline"]))
    facts.append(Metric(name="nproc", value=ansible_facts["ansible_processor_nproc"]))
    # TODO: would prefer to express this in a way that captures units.
    facts.append(Metric(name="memory", value=ansible_facts["ansible_memtotal_mb"], unit="MB"))
    ansible_ansible_facts = ansible_facts["ansible_facts"] # wat
    facts.append(Metric(name="kernel_version", value=ansible_ansible_facts["kernel"]))

    ts = ansible_facts["ansible_date_time"]["iso8601_micro"]
    facts.append(Metric(name="timestamp", value=datetime.datetime.fromisoformat(ts)))

    # ansible_processor seems to be a list where each consecutive 3 pairs is
    # (processor number, vendor, model)
    ansible_processor = ansible_facts["ansible_processor"]
  except KeyError as e:
    raise EnrichmentFailure("missing field in ansible all_facts") from e

  try:
    p = ansible_processor
    cpu_models = {int(p[i]): (p[i+1] + " " + p[i+2]) for i in range(0, len(p), 3)}
    facts.append(Metric(name="cpu", value=" + ".join(set(cpu_models.values()))))

  except Exception as e:
    raise EnrichmentFailure("failed to parse ansible_processor mess") from e

  # TODO: Need to figure out how to encode my knowledge about whose cmdline this is and ideally where it came from.
  #       Probably when I write the results to the database I should be dropping some metadata
  #       saying that this is an ansible fact dump and how it relates to the SUT.
  return (facts, [])

def enrich_from_phoronix_json(artifact: Artifact) -> Tuple[Sequence[Fact], Sequence[Metric]]:
  if not fnmatch(artifact.path, "**/pts-results.json"):
    return {}, []
  try:
    obj = json.loads(artifact.content())
  except json.decoder.JSONDecodeError as e:
    raise EnrichmentFailure() from e
  metrics = []

  try:
    # In the current data I"m looking at, the key here isa timestamp with no timezone
    for result in obj["results"].values():
      if result["identifier"] != "pts/fio-2.1.0":
        print(f"Ignoring unknown Phoronix result with identifier: {result['identifier']}")
        continue
      # TODO: do we want some general capability for hierarchical results? For now
      # we'll just store metrics directly as items in the result and then flatten
      # this later into a DF or whatever that's easy to do analysis on.
      for subresult in result["results"].values():
        for value in subresult["raw_values"]:
          args = result["arguments"]
          scale = result["scale"]
          metrics.append(Metric(name=f"PTS FIO [{args}] {scale}",
                                value=value,
                                unit=result["scale"]))
  except KeyError as e:
    raise EnrichmentFailure("missing expected field in phoronix-test-suite-result.json") from e
  return {}, metrics

def enrich_from_sysfs_tgz(artifact: Artifact) -> Tuple[Sequence[Fact], Sequence[Metric]]:
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
            facts.append(Metric(name=f"sysfs_cpu_vuln:{os.path.basename(member.name)}", value=content.strip('\0').strip()))
    return facts, []
  except Exception as e:
    raise EnrichmentFailure() from e

# TODO: Should each kconfig actually be a separate fact? Maybe facts shoudl inherently be nesting...
def enrich_from_kconfig(artifact: Artifact) -> Tuple[Sequence[Fact], Sequence[Metric]]:
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
  return [Metric(name="kconfig", value=kconfig_dict)], []

ENRICHERS = [
    enrich_from_ansible, enrich_from_phoronix_json, enrich_from_sysfs_tgz,
    enrich_from_kconfig,
]
