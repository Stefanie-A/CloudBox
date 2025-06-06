FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt . 

RUN pip install --no-cache-dir -r requirements.txt

ENV AWS_DEFAULT_REGION=us-east-1

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
