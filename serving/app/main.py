"""
FastAPI application that loads the Production churn model from MLflow
and serves predictions via a REST API.

Endpoints:
  GET  /health   → liveness + model info
  POST /predict  → churn probability for a single customer
"""

import os
import logging
from contextlib import asynccontextmanager

import mlflow
import mlflow.sklearn
import pandas as pd
from fastapi import FastAPI, HTTPException
from mlflow.tracking import MlflowClient

from app.schemas import CustomerFeatures, PredictionResponse, HealthResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ── Configuration (from environment variables / ECS task definition) ───────────
MLFLOW_TRACKING_URI = os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000")
MODEL_NAME          = os.environ.get("MODEL_NAME", "churn-model")
MODEL_STAGE         = os.environ.get("MODEL_STAGE", "Production")

# Global model state
_model = None
_model_version = None


def load_model():
    global _model, _model_version

    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    client = MlflowClient()

    model_uri = f"models:/{MODEL_NAME}/{MODEL_STAGE}"
    log.info("Loading model from %s", model_uri)

    _model = mlflow.sklearn.load_model(model_uri)

    # Retrieve the version number for observability
    versions = client.get_latest_versions(MODEL_NAME, stages=[MODEL_STAGE])
    _model_version = versions[0].version if versions else "unknown"

    log.info("Loaded model version %s", _model_version)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, clean up on shutdown."""
    load_model()
    yield
    log.info("Shutting down")


app = FastAPI(
    title="Churn Prediction API",
    description="Predicts customer churn probability using a GBM model served from MLflow.",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health", response_model=HealthResponse, tags=["ops"])
def health():
    if _model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return HealthResponse(
        status="ok",
        model_name=MODEL_NAME,
        model_stage=MODEL_STAGE,
        model_version=_model_version,
    )


@app.post("/predict", response_model=PredictionResponse, tags=["inference"])
def predict(features: CustomerFeatures):
    if _model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    input_df = pd.DataFrame([features.model_dump()])

    try:
        prob = float(_model.predict_proba(input_df)[0][1])
        churn = prob >= 0.5
    except Exception as exc:
        log.exception("Prediction failed")
        raise HTTPException(status_code=500, detail=str(exc))

    return PredictionResponse(
        churn=churn,
        churn_probability=round(prob, 4),
        model_version=_model_version or "unknown",
    )
