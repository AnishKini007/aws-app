"""
Evaluate the latest MLflow run against quality thresholds.
If thresholds pass, promote the model version to 'Production'.

This script is the quality gate in the CI/CD pipeline:
  - exit 0  → model is good, proceed to Docker build + deploy
  - exit 1  → model failed quality gate, pipeline aborts

Usage:
    python src/evaluate.py --run-id <run-id>
"""

import os
import sys
import argparse
import mlflow
from mlflow.tracking import MlflowClient
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ── Quality thresholds ─────────────────────────────────────────────────────────
THRESHOLDS = {
    "roc_auc":  0.75,
    "f1":       0.55,
    "accuracy": 0.78,
}

MODEL_NAME = "churn-model"


def get_run_metrics(client: MlflowClient, run_id: str) -> dict:
    run = client.get_run(run_id)
    return run.data.metrics


def passes_thresholds(metrics: dict) -> bool:
    all_pass = True
    for metric, threshold in THRESHOLDS.items():
        value = metrics.get(metric, 0)
        status = "PASS" if value >= threshold else "FAIL"
        log.info("  %-12s %.4f (threshold %.2f) → %s", metric, value, threshold, status)
        if value < threshold:
            all_pass = False
    return all_pass


def promote_to_production(client: MlflowClient, run_id: str):
    """Find the model version registered in this run and transition it to Production."""
    versions = client.search_model_versions(f"name='{MODEL_NAME}'")
    # Find the version tied to this run
    for v in sorted(versions, key=lambda x: int(x.version), reverse=True):
        if v.run_id == run_id:
            # Archive the current Production version first
            prod_versions = [
                mv for mv in versions
                if mv.current_stage == "Production" and mv.version != v.version
            ]
            for pv in prod_versions:
                client.transition_model_version_stage(
                    name=MODEL_NAME,
                    version=pv.version,
                    stage="Archived",
                )
                log.info("Archived previous Production version %s", pv.version)

            # Promote this version
            client.transition_model_version_stage(
                name=MODEL_NAME,
                version=v.version,
                stage="Production",
            )
            log.info("Promoted version %s to Production", v.version)

            # Tag it
            client.set_model_version_tag(MODEL_NAME, v.version, "promoted_by", "ci-pipeline")
            return

    log.error("No model version found for run %s", run_id)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id",  default=None,
                        help="MLflow run ID (defaults to contents of mlflow_run_id.txt)")
    args = parser.parse_args()

    run_id = args.run_id
    if not run_id:
        with open("mlflow_run_id.txt") as f:
            run_id = f.read().strip()

    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    client = MlflowClient()

    log.info("Evaluating run: %s", run_id)
    metrics = get_run_metrics(client, run_id)

    log.info("--- Quality Gate ---")
    if passes_thresholds(metrics):
        log.info("Quality gate PASSED — promoting model to Production")
        promote_to_production(client, run_id)
        sys.exit(0)
    else:
        log.error("Quality gate FAILED — model will NOT be deployed")
        sys.exit(1)


if __name__ == "__main__":
    main()
