# Python 3.9 환경을 기반 이미지로 사용
FROM python:3.9-slim

# 작업 디렉토리 설정
WORKDIR /app

# 필요한 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# API 스크립트와 모델 파일 복사
COPY app.py .
COPY vehicle_price_prediction.joblib .

# FastAPI 애플리케이션 실행 포트 지정
EXPOSE 8000

# 서버 실행 명령어 (Uvicorn을 사용하여 app.py의 FastAPI 앱을 실행)
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
