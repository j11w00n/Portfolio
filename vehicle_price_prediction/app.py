# ----------------------------------------------------
# FastAPI 기반의 모델 예측 API 스크립트 (app.py)
# ----------------------------------------------------

from fastapi import FastAPI
from pydantic import BaseModel, Field
import joblib
import pandas as pd
import numpy as np

# 최종 학습 피처 리스트
FINAL_FEATURES = ['year', 'mileage', 'engine_hp', 'owner_count', 'vehicle_age', 
                  'mileage_per_year', 'brand_popularity', 'mileage_log', 'mean_encoded_make', 
                  'mean_encoded_model', 'accident_severity', 'accident_flag', 'transmission_Manual', 
                  'fuel_type_Electric', 'fuel_type_Gasoline', 'drivetrain_FWD', 'drivetrain_RWD', 
                  'body_type_Hatchback', 'body_type_Minivan', 'body_type_Pickup Truck', 'body_type_SUV', 
                  'body_type_Sedan', 'body_type_Wagon', 'exterior_color_Blue', 'exterior_color_Gray', 
                  'exterior_color_Red', 'exterior_color_Silver', 'exterior_color_White', 'interior_color_Black', 
                  'interior_color_Brown', 'interior_color_Gray', 'seller_type_Private', 'condition_Fair', 
                  'condition_Good', 'trim_EX', 'trim_LX', 'trim_Limited', 'trim_Sport', 'trim_Touring']

try:
    model = joblib.load('vehicle_price_prediction.joblib')
except FileNotFoundError:
    raise RuntimeError("vehicle_price_prediction.joblib 파일을 찾을 수 없습니다.")

app = FastAPI()

# 2. API 입력 데이터 구조 정의
class CarFeatures(BaseModel):
    # 원본 수치형/계산된 피처 (원본 값으로 가정)
    year: int = Field(..., description="차량 연식")
    mileage: float = Field(..., description="주행 거리")
    engine_hp: int = Field(..., description="엔진 마력")
    owner_count: int = Field(..., description="이전 소유자 수")
    accident_severity: int = Field(..., description="사고 심각도")
    accident_flag: int = Field(..., description="사고 유무")
    brand_popularity: float = Field(..., description="브랜드 인기도")
   
    # 원본 범주형 피처 (문자열로 입력)
    transmission: str = Field(..., description="변속기")
    fuel_type: str = Field(..., description="연료 타입")
    drivetrain: str = Field(..., description="구동 방식")
    body_type: str = Field(..., description="차체 형태")
    exterior_color: str = Field(..., description="외부 색상")
    interior_color: str = Field(..., description="내부 색상")
    seller_type: str = Field(..., description="판매자 타입")
    condition: str = Field(..., description="차량 상태")
    trim: str = Field(..., description="트림")
   
    # mean_encoded_make와 mean_encoded_model을 구현하기 위해 원본 'make'와 'model' 추가
    make: str = Field(..., description="제조사 이름")
    model_name: str = Field(..., description="모델 이름")


@app.get("/")
def read_root():
    return {"message": "Vehicle Price Prediction API is running."}

@app.post("/predict")
def predict_price(features: CarFeatures):
    data = features.dict()
    df = pd.DataFrame([data])
   
    # ---------------------------------------------------------
    # A. 파생 변수 계산 및 로그 변환
    df['mileage_log'] = np.log1p(df['mileage'])
    df['vehicle_age'] = 2023 - df['year'] # 현재 연도 가정
    df['mileage_per_year'] = df['mileage'] / df['vehicle_age']

    # B. 범주형 변수 원-핫 인코딩 재현
    categorical_cols = ['transmission', 'fuel_type', 'drivetrain', 'body_type',
                        'exterior_color', 'interior_color', 'seller_type',
                        'condition', 'trim']
    df = pd.get_dummies(df, columns=categorical_cols)

    # C. 최종 모델 피처 재정렬 및 누락 피처(Dummy) 추가
   
    # 최종 피처셋 DataFrame 생성 (모든 컬럼을 0으로 초기화)
    final_df = pd.DataFrame(0, index=[0], columns=FINAL_FEATURES)
   
    # 1. 재구축된 df의 값을 final_df에 업데이트
    for col in df.columns:
        if col in final_df.columns:
            final_df[col] = df[col]
           
    # 2. Mean Encoding 피처 처리
    # 맵핑 테이블이 없으므로 일단 0.0으로 임시 처리
    if 'mean_encoded_make' in FINAL_FEATURES:
        final_df['mean_encoded_make'] = final_df['mean_encoded_make'].fillna(0.0)
    if 'mean_encoded_model' in FINAL_FEATURES:
        final_df['mean_encoded_model'] = final_df['mean_encoded_model'].fillna(0.0)

    # D. 모델 예측 (최종 피처셋 사용)
    log_prediction = model.predict(final_df)[0]
   
    # E. 예측 결과 역변환
    prediction = np.expm1(log_prediction)

    return {"predicted_price": round(float(prediction), 2)}
