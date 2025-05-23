import unittest
from pathlib import Path
import re
from src.falba.enrichers import (
    enrich_from_os_release,
    enrich_from_fio_json_plus,
    enrich_from_nixos_version_json,
    enrich_from_bpftrace_logs,
)
from src.falba.model import Artifact, Fact, Metric
import json

# Defines the base path to the test data directory relative to this test file.
# __file__ (src/falba/tests/test_enrichers.py) -> parent (src/falba/tests) -> parent (src/falba) -> "testdata"
testdata_dir = Path(__file__).resolve().parent.parent / "testdata"

class TestEnrichFromOsRelease(unittest.TestCase):
    def test_enrich_os_release(self):
        test_definitions = [
            (
                testdata_dir / "results/nixos-asi-benchmarks:836d59863d4a/artifacts/etc_os-release",
                Fact(name="os_release_variant_id", value="aethelred-asi-on")
            ),
            (
                testdata_dir / "results/nixos-asi-benchmarks:d6b0e7e4b7b4/artifacts/etc_os-release",
                Fact(name="os_release_variant_id", value="aethelred-asi-off")
            ),
        ]

        for test_file_path, expected_fact in test_definitions:
            artifact = Artifact(path=test_file_path)
            facts, _ = enrich_from_os_release(artifact)
            self.assertIn(expected_fact, facts,
                          f"Fact {expected_fact!r} not found in {facts!r} for file {test_file_path}")


class TestEnrichFromFioJsonPlus(unittest.TestCase):
    def test_enrich_fio_json_plus(self):
        test_definitions = [
            (
                testdata_dir / "results/nixos-asi-benchmarks:836d59863d4a/artifacts/fio_output.json",
                [
                    Metric(name="fio_randread_read_lat_ns_mean", value=56960.234619),
                    Metric(name="fio_randread_read_slat_ns_mean", value=0.0),
                    Metric(name="fio_randread_read_clat_ns_mean", value=56932.733276),
                    Metric(name="fio_randread_read_iops", value=17448.349308),
                ]
            ),
            (
                testdata_dir / "results/nixos-asi-benchmarks:d6b0e7e4b7b4/artifacts/fio_output.json",
                [
                    Metric(name="fio_randread_read_lat_ns_mean", value=52777.721008),
                    Metric(name="fio_randread_read_slat_ns_mean", value=0.0),
                    Metric(name="fio_randread_read_clat_ns_mean", value=52755.286926),
                    Metric(name="fio_randread_read_iops", value=18853.855006),
                ]
            )
        ]

        for file_path, expected_metrics_list in test_definitions:
            artifact = Artifact(path=file_path)
            facts, metrics = enrich_from_fio_json_plus(artifact)
            self.assertEqual(facts, [], "Expected no facts from enrich_from_fio_json_plus")

            # Check if all expected metrics are present
            for expected_metric in expected_metrics_list:
                self.assertIn(expected_metric, metrics, msg=f"{expected_metric!r} not found for {file_path}")
            
            # Check if no unexpected metrics are present
            self.assertEqual(len(metrics), len(expected_metrics_list), 
                             msg=f"Unexpected number of metrics for {file_path}. Expected {len(expected_metrics_list)}, got {len(metrics)}. Metrics found: {metrics!r}")


class TestEnrichFromNixosVersionJson(unittest.TestCase):
    def test_enrich_nixos_version_json(self):
        test_definitions = [
            (
                testdata_dir / "results/nixos-asi-benchmarks:836d59863d4a/artifacts/nixos-version.json",
                Fact(name="nixos_configuration_revision", value="1254e976fb3bfe9ea80a6a23e9456248149f36eb")
            ),
            (
                testdata_dir / "results/nixos-asi-benchmarks:d6b0e7e4b7b4/artifacts/nixos-version.json",
                Fact(name="nixos_configuration_revision", value="f1034e1fd7e67e1a4297386446a1339727abf647")
            )
        ]

        for file_path, expected_fact in test_definitions:
            artifact = Artifact(path=file_path)
            facts, metrics = enrich_from_nixos_version_json(artifact)
            
            self.assertEqual(metrics, [], "Expected no metrics from enrich_from_nixos_version_json")
            self.assertIn(expected_fact, facts, msg=f"{expected_fact!r} not found for {file_path}")
            self.assertEqual(len(facts), 1, 
                             msg=f"Expected 1 fact for {file_path}, got {len(facts)}. Facts found: {facts!r}")


class TestEnrichFromBpftraceLogs(unittest.TestCase):
    def test_enrich_bpftrace_logs(self):
        test_file_path_suffix = "results/nixos-asi-benchmarks:836d59863d4a/artifacts/bpftrace_asi_exits.log"
        test_file_path = testdata_dir / test_file_path_suffix

        artifact = Artifact(path=test_file_path)
        facts, metrics = enrich_from_bpftrace_logs(artifact)

        # Parse the test file to find the expected value for asi_exits
        expected_asi_exits_value = None
        with open(test_file_path, "r") as f:
            for line in f:
                if line.startswith("@total_exits:"):
                    match = re.search(r"\d+", line)
                    if match:
                        expected_asi_exits_value = int(match.group(0))
                        break
        
        self.assertIsNotNone(expected_asi_exits_value, "Could not parse asi_exits from log file")

        self.assertIn(Fact(name="instrumented", value=True), facts)
        self.assertIn(Metric(name="asi_exits", value=expected_asi_exits_value), metrics)


if __name__ == "__main__":
    unittest.main()
