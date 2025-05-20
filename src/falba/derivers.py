from collections.abc import Sequence
from typing import Dict, List, Self, Any, Optional, Callable, Tuple

def derive_asi_on(result: Result) -> Tuple[Sequence[Fact], Sequence[Metric]]:
  try:
    kconfig = result.facts['kconfig'].value
    cmdline_fields = result.facts['cmdline_fields'].value
  except KeyError as e:
    print(f"{result.result_id}: Couldn't derive ASI enablement: missing {e}")
    return [], []

  asi_builtin = kconfig.get('CONFIG_MITIGATION_ADDRESS_SPACE_ISOLATION') == 'y'
  if asi_builtin:
    asi_default_on = kconfig.get('CONFIG_ADDRESS_SPACE_ISOLATION_DEFAULT_ON') == 'y'
    if asi_default_on:
      asi_on = cmdline_fields.get('asi') != 'off'
    else:
      asi_on = cmdline_fields.get('asi') == 'on'
    if asi_on:
      if cmdline_fields.get('asi_userspace') == 'off':
        fact_val='kvm_only'
      else:
        fact_val='yes'
    else:
      fact_val='no'
  else:
    fact_val = 'no'

  return ([Metric(name="asi_on", value=fact_val)], [])
db.derive_with(derive_asi_on)

def derive_retbleed_mitigation(result: Result) -> Tuple[Sequence[Fact], Sequence[Metric]]:
  try:
    asi_on = result.facts['asi_on'].value
    sysfs_mit = result.facts['sysfs_cpu_vuln:retbleed'].value
  except KeyError:
    print(f"{result.result_id}: couldn't derive retbleed mitigation, facts:, {result.facts.keys()}")
    return [], []

  if not asi_on:
    mit = sysfs_mit
  elif sysfs_mit != "Vulnerable":
    mit = f"ASI + {sysfs_mit}"
  else:
    mit = "ASI"

  return  ([Metric(name="retbleed_mitigation", value=mit )], [])
db.derive_with(derive_retbleed_mitigation)