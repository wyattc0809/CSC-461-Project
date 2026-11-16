"""Admission rate model.

Grain: one row per (patient, month start).
Label: 1 if the patient has an inpatient or emergency encounter in the next 30 days.

The classifier predicts each patient's 30-day admission probability. Summing those
probabilities over everyone alive at a month start gives the expected number of
admitted patients, which is reported as a rate per 1,000 patients. That is what a
hospital would use for bed and staff planning.
"""
from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import average_precision_score, brier_score_loss, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

NUMERIC_FEATURES = [
    "age_years",
    "income",
    "prior_admits_365",
    "prior_ed_90",
    "prior_visits_365",
    "days_since_last_admit",   # NULL = no admission in the past year (the model handles NaN natively)
    "active_conditions",
    "active_meds",
    "latest_bmi",
    "month_of_year",           # seasonality
]
CATEGORICAL_FEATURES = ["gender"]
TARGET = "label"


def time_split(df: pd.DataFrame, train_end: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    cutoff = pd.Timestamp(train_end)
    dates = pd.to_datetime(df["snapshot_date"])
    return df[dates < cutoff], df[dates >= cutoff]

class AdmissionRateModel:
    def __init__(self, seed: int):
        self.pipe = Pipeline([
            ("prep", ColumnTransformer(
                [("cat", OneHotEncoder(handle_unknown="ignore", sparse_output=False), CATEGORICAL_FEATURES)],
                remainder="passthrough",
            )),
            ("clf", HistGradientBoostingClassifier(
                max_iter=300,
                learning_rate=0.05,
                class_weight="balanced",    # admissions are about 1-2% of rows
                random_state=seed,          # fixed seed, so both variants get identical training
            )),
        ])

    @staticmethod
    def _X(df: pd.DataFrame) -> pd.DataFrame:
        X = df[CATEGORICAL_FEATURES + NUMERIC_FEATURES].copy()
        X[NUMERIC_FEATURES] = X[NUMERIC_FEATURES].astype("float64")   # pyodbc returns DECIMAL as Decimal
        return X

    def fit(self, train: pd.DataFrame) -> "AdmissionRateModel":
        self.pipe.fit(self._X(train), train[TARGET].astype(int))
        return self

    def predict_proba(self, df: pd.DataFrame) -> np.ndarray:
        return self.pipe.predict_proba(self._X(df))[:, 1]

    def monthly_rates(self, df: pd.DataFrame) -> pd.DataFrame:
        """Predicted vs. actual 30-day admission rate per 1,000 patients, by month."""
        scored = df.assign(p=self.predict_proba(df))
        out = scored.groupby("snapshot_date").agg(
            population=(TARGET, "size"),
            actual=(TARGET, "sum"),
            expected=("p", "sum"),
        )
        out["actual_per_1000"] = 1000 * out["actual"] / out["population"]
        out["predicted_per_1000"] = 1000 * out["expected"] / out["population"]
        return out

    def evaluate(self, test: pd.DataFrame) -> dict[str, float]:
        y = test[TARGET].astype(int)
        p = self.predict_proba(test)
        rates = self.monthly_rates(test)
        return {
            "auroc": roc_auc_score(y, p),
            "pr_auc": average_precision_score(y, p),
            "brier": brier_score_loss(y, p),
            "monthly_rate_mae_per_1000": float(
                (rates["predicted_per_1000"] - rates["actual_per_1000"]).abs().mean()
            ),
        }


    """Split by snapshot date, never at random, so the model never sees the future."""
