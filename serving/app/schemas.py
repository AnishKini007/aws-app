"""Pydantic schemas for request/response validation."""

from pydantic import BaseModel, Field
from typing import Optional


class CustomerFeatures(BaseModel):
    tenure: int                  = Field(..., ge=0,  description="Months with the company")
    MonthlyCharges: float        = Field(..., ge=0,  description="Monthly charge amount")
    TotalCharges: float          = Field(..., ge=0,  description="Total charges to date")
    gender: int                  = Field(..., ge=0, le=1)
    Partner: int                 = Field(..., ge=0, le=1)
    Dependents: int              = Field(..., ge=0, le=1)
    PhoneService: int            = Field(..., ge=0, le=1)
    MultipleLines: int           = Field(..., ge=0, le=2)
    InternetService: int         = Field(..., ge=0, le=2)
    OnlineSecurity: int          = Field(..., ge=0, le=2)
    OnlineBackup: int            = Field(..., ge=0, le=2)
    DeviceProtection: int        = Field(..., ge=0, le=2)
    TechSupport: int             = Field(..., ge=0, le=2)
    StreamingTV: int             = Field(..., ge=0, le=2)
    StreamingMovies: int         = Field(..., ge=0, le=2)
    Contract: int                = Field(..., ge=0, le=2, description="0=Month-to-month, 1=One year, 2=Two year")
    PaperlessBilling: int        = Field(..., ge=0, le=1)
    PaymentMethod: int           = Field(..., ge=0, le=3)

    class Config:
        json_schema_extra = {
            "example": {
                "tenure": 12,
                "MonthlyCharges": 65.0,
                "TotalCharges": 780.0,
                "gender": 0,
                "Partner": 1,
                "Dependents": 0,
                "PhoneService": 1,
                "MultipleLines": 0,
                "InternetService": 0,
                "OnlineSecurity": 0,
                "OnlineBackup": 1,
                "DeviceProtection": 0,
                "TechSupport": 0,
                "StreamingTV": 0,
                "StreamingMovies": 0,
                "Contract": 0,
                "PaperlessBilling": 1,
                "PaymentMethod": 0,
            }
        }


class PredictionResponse(BaseModel):
    churn: bool               = Field(..., description="True if customer is predicted to churn")
    churn_probability: float  = Field(..., description="Probability of churn (0–1)")
    model_version: str        = Field(..., description="MLflow model version that served this prediction")


class HealthResponse(BaseModel):
    status: str
    model_name: str
    model_stage: str
    model_version: Optional[str]
