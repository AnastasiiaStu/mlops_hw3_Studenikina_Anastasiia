import os
import pickle
import logging
from datetime import datetime
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import numpy as np

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ML Prediction Service",
    description="для инференса ML-модели",
    version=os.getenv("MODEL_VERSION", "v1.0.0")
)

model = None
MODEL_VERSION = os.getenv("MODEL_VERSION", "v1.0.0")


class PredictionRequest(BaseModel):
    features: List[float]
    
    class Config:
        json_schema_extra = {
            "example": {
                "features": [5.1, 3.5, 1.4, 0.2]
            }
        }


class PredictionResponse(BaseModel):
    prediction: int
    model_version: str
    timestamp: str


class HealthResponse(BaseModel):
    status: str
    version: str
    model_loaded: bool


def load_model():

    global model
    try:
        model_path = "app/model.pkl"
        
        if not os.path.exists(model_path):
            logger.warning(f"Model file not found at {model_path}, creating dummy model")
            from sklearn.ensemble import RandomForestClassifier
            from sklearn.datasets import load_iris
            
            X, y = load_iris(return_X_y=True)
            model = RandomForestClassifier(n_estimators=10, random_state=42)
            model.fit(X, y)
            
            with open(model_path, 'wb') as f:
                pickle.dump(model, f)
            logger.info("Dummy model created and saved")
        else:
            with open(model_path, 'rb') as f:
                model = pickle.load(f)
            logger.info(f"Model loaded successfully from {model_path}")
        
        logger.info(f"Model version: {MODEL_VERSION}")
        return True
        
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        return False


@app.on_event("startup")
async def startup_event():

    logger.info(f"Starting ML Service version {MODEL_VERSION}")
    success = load_model()
    if not success:
        logger.error("Failed to load model on startup")
    else:
        logger.info("Service started successfully")


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "ML Prediction Service",
        "version": MODEL_VERSION,
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "docs": "/docs"
        }
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health():

    logger.info("Health check requested")
    
    return HealthResponse(
        status="ok",
        version=MODEL_VERSION,
        model_loaded=model is not None
    )


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict(request: PredictionRequest):

    start_time = datetime.now()
    
    if model is None:
        logger.error("Model not loaded")
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        logger.info(f"Prediction request received: {request.features}")
        
        features_array = np.array(request.features).reshape(1, -1)
        prediction = model.predict(features_array)
        prediction_value = int(prediction[0])
        
        inference_time = (datetime.now() - start_time).total_seconds()
        logger.info(f"Prediction: {prediction_value}, Inference time: {inference_time:.4f}s")
        
        return PredictionResponse(
            prediction=prediction_value,
            model_version=MODEL_VERSION,
            timestamp=datetime.now().isoformat()
        )
        
    except ValueError as e:
        logger.error(f"Invalid input data: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Invalid input data: {str(e)}")
    
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


@app.get("/metrics", tags=["Monitoring"])
async def metrics():

    return {
        "model_version": MODEL_VERSION,
        "model_loaded": model is not None,
        "status": "healthy" if model is not None else "unhealthy"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)