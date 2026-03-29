"""
Preprocessing for the Telco Customer Churn dataset.

Input:  raw CSV downloaded from S3 (or local data/ directory)
Output: processed train/test splits saved to data/processed/
"""

import os
import argparse
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# Columns we keep after cleaning
NUMERIC_COLS = ["tenure", "MonthlyCharges", "TotalCharges"]
CATEGORICAL_COLS = [
    "gender", "Partner", "Dependents", "PhoneService", "MultipleLines",
    "InternetService", "OnlineSecurity", "OnlineBackup", "DeviceProtection",
    "TechSupport", "StreamingTV", "StreamingMovies", "Contract",
    "PaperlessBilling", "PaymentMethod",
]
TARGET_COL = "Churn"


def load_raw(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    log.info("Loaded %d rows from %s", len(df), path)
    return df


def clean(df: pd.DataFrame) -> pd.DataFrame:
    # Drop customer ID — not a feature
    df = df.drop(columns=["customerID"], errors="ignore")

    # TotalCharges is sometimes a string with spaces
    df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce")

    # Fill missing TotalCharges with MonthlyCharges * tenure (new customers)
    mask = df["TotalCharges"].isna()
    df.loc[mask, "TotalCharges"] = df.loc[mask, "MonthlyCharges"] * df.loc[mask, "tenure"]

    # Binary target
    df[TARGET_COL] = (df[TARGET_COL].str.strip().str.lower() == "yes").astype(int)

    return df


def encode_categoricals(df: pd.DataFrame) -> pd.DataFrame:
    for col in CATEGORICAL_COLS:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
    return df


def split_and_save(df: pd.DataFrame, output_dir: str, test_size: float, random_state: int):
    os.makedirs(output_dir, exist_ok=True)

    feature_cols = NUMERIC_COLS + CATEGORICAL_COLS
    X = df[[c for c in feature_cols if c in df.columns]]
    y = df[TARGET_COL]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=random_state, stratify=y
    )

    train_df = X_train.copy()
    train_df[TARGET_COL] = y_train.values
    test_df = X_test.copy()
    test_df[TARGET_COL] = y_test.values

    train_path = os.path.join(output_dir, "train.csv")
    test_path  = os.path.join(output_dir, "test.csv")

    train_df.to_csv(train_path, index=False)
    test_df.to_csv(test_path, index=False)

    log.info("Train: %d rows → %s", len(train_df), train_path)
    log.info("Test:  %d rows → %s", len(test_df), test_path)
    log.info("Churn rate — train: %.2f%%  test: %.2f%%",
             y_train.mean() * 100, y_test.mean() * 100)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input",        default="data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv")
    parser.add_argument("--output-dir",   default="data/processed")
    parser.add_argument("--test-size",    type=float, default=0.2)
    parser.add_argument("--random-state", type=int,   default=42)
    args = parser.parse_args()

    df = load_raw(args.input)
    df = clean(df)
    df = encode_categoricals(df)
    split_and_save(df, args.output_dir, args.test_size, args.random_state)


if __name__ == "__main__":
    main()
