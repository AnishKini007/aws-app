"""Unit tests for the preprocessing pipeline."""

import pytest
import pandas as pd
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from src.preprocess import clean, encode_categoricals, TARGET_COL, NUMERIC_COLS


@pytest.fixture
def raw_sample():
    return pd.DataFrame({
        "customerID":      ["1111-AAA", "2222-BBB", "3333-CCC"],
        "tenure":          [12, 0, 24],
        "MonthlyCharges":  [50.0, 70.0, 90.0],
        "TotalCharges":    ["600.0", " ", "2160.0"],  # space simulates bad data
        "gender":          ["Male", "Female", "Male"],
        "Partner":         ["Yes", "No", "Yes"],
        "Dependents":      ["No", "No", "Yes"],
        "PhoneService":    ["Yes", "No", "Yes"],
        "MultipleLines":   ["No", "No phone service", "Yes"],
        "InternetService": ["DSL", "Fiber optic", "No"],
        "OnlineSecurity":  ["No", "Yes", "No internet service"],
        "OnlineBackup":    ["Yes", "No", "No internet service"],
        "DeviceProtection":["No", "Yes", "No internet service"],
        "TechSupport":     ["No", "No", "No internet service"],
        "StreamingTV":     ["No", "No", "No internet service"],
        "StreamingMovies": ["No", "No", "No internet service"],
        "Contract":        ["Month-to-month", "One year", "Two year"],
        "PaperlessBilling":["Yes", "No", "Yes"],
        "PaymentMethod":   ["Electronic check", "Mailed check", "Bank transfer (automatic)"],
        "Churn":           ["No", "Yes", "No"],
    })


def test_clean_removes_customer_id(raw_sample):
    result = clean(raw_sample)
    assert "customerID" not in result.columns


def test_clean_converts_total_charges(raw_sample):
    result = clean(raw_sample)
    assert result["TotalCharges"].dtype == float


def test_clean_fills_missing_total_charges(raw_sample):
    result = clean(raw_sample)
    # Row 1: tenure=0, MonthlyCharges=70 → TotalCharges should be 0.0
    assert result.loc[1, "TotalCharges"] == pytest.approx(0.0)


def test_clean_binary_target(raw_sample):
    result = clean(raw_sample)
    assert set(result[TARGET_COL].unique()).issubset({0, 1})
    assert result.loc[0, TARGET_COL] == 0  # "No"
    assert result.loc[1, TARGET_COL] == 1  # "Yes"


def test_encode_categoricals_are_numeric(raw_sample):
    df = clean(raw_sample)
    df = encode_categoricals(df)
    for col in ["gender", "Partner", "Contract"]:
        assert pd.api.types.is_numeric_dtype(df[col]), f"{col} should be numeric"


def test_no_nulls_after_clean(raw_sample):
    result = clean(raw_sample)
    assert result[NUMERIC_COLS].isna().sum().sum() == 0
