"""
Train a Gradient Boosting classifier for churn prediction.
Logs all params, metrics, and the model artifact to MLflow.

Usage:
    python src/train.py --params params.yaml
"""

import os
import argparse
import yaml
import pandas as pd
import mlflow
import mlflow.sklearn
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import (
    accuracy_score, f1_score, roc_auc_score,
    precision_score, recall_score,
)
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

TARGET_COL = "Churn"


def load_data(train_path: str, test_path: str):
    train = pd.read_csv(train_path)
    test  = pd.read_csv(test_path)
    X_train = train.drop(columns=[TARGET_COL])
    y_train = train[TARGET_COL]
    X_test  = test.drop(columns=[TARGET_COL])
    y_test  = test[TARGET_COL]
    return X_train, y_train, X_test, y_test


def compute_metrics(y_true, y_pred, y_prob) -> dict:
    return {
        "accuracy":  accuracy_score(y_true, y_pred),
        "f1":        f1_score(y_true, y_pred),
        "roc_auc":   roc_auc_score(y_true, y_prob),
        "precision": precision_score(y_true, y_pred),
        "recall":    recall_score(y_true, y_pred),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--params",     default="params.yaml")
    parser.add_argument("--train-data", default="data/processed/train.csv")
    parser.add_argument("--test-data",  default="data/processed/test.csv")
    args = parser.parse_args()

    with open(args.params) as f:
        params = yaml.safe_load(f)["train"]

    X_train, y_train, X_test, y_test = load_data(args.train_data, args.test_data)

    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    mlflow.set_experiment("churn-prediction")

    with mlflow.start_run() as run:
        log.info("MLflow run: %s", run.info.run_id)

        # Log dataset metadata as tags
        mlflow.set_tags({
            "dataset":       "telco-churn",
            "train_samples": len(X_train),
            "test_samples":  len(X_test),
            "git_commit":    os.environ.get("GITHUB_SHA", "local"),
        })

        mlflow.log_params(params)

        model = GradientBoostingClassifier(
            n_estimators=params["n_estimators"],
            max_depth=params["max_depth"],
            learning_rate=params["learning_rate"],
            subsample=params["subsample"],
            random_state=params["random_state"],
        )

        model.fit(X_train, y_train)

        y_pred = model.predict(X_test)
        y_prob = model.predict_proba(X_test)[:, 1]

        metrics = compute_metrics(y_test, y_pred, y_prob)
        mlflow.log_metrics(metrics)

        for name, value in metrics.items():
            log.info("  %-12s %.4f", name, value)

        # Log model with input signature for type safety in serving
        signature = mlflow.models.infer_signature(X_train, y_pred)
        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path="model",
            signature=signature,
            registered_model_name="churn-model",
        )

        log.info("Model logged to MLflow run %s", run.info.run_id)

        # Write run ID to file so evaluate.py can pick it up
        with open("mlflow_run_id.txt", "w") as f:
            f.write(run.info.run_id)


if __name__ == "__main__":
    main()
