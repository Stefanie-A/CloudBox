import os
import jwt
import base64
import requests
import datetime
from flask import Flask, request, jsonify, session
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
SECRET_KEY = os.getenv("JWT_SECRET", "mysecretkey")
LAMBDA_UPLOAD_URL = os.getenv('LAMBDA_UPLOAD_URL')
app.secret_key = os.urandom(24)

@app.route('/login', methods=['POST'])
def login():
    email = request.json.get('email')
    password = request.json.get('password')

    if email != 'admin@example.com' or password != 'password':
        return jsonify({"error": "Invalid credentials"}), 401

    token = jwt.encode({
        'email': email,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1)
    }, SECRET_KEY, algorithm='HS256')

    print("Generated Token:", token)  # ✅ Now it will print!

    return jsonify({"token": token})

@app.route('/upload', methods=['POST'])
def upload():
    token = request.headers.get('Authorization')

    if not token:
        return jsonify({"error": "No token provided"}), 401
    
    file = request.files.get('file')
    if not file:
        return jsonify({"error": "No file provided"}), 400

    file_content = file.read()
    encoded_file = base64.b64encode(file_content).decode('utf-8')

    payload = {
        "file_name": file.filename,
        "file_content": encoded_file
    }

    headers = {"Authorization": token}

    response = requests.post(LAMBDA_UPLOAD_URL, json=payload, headers=headers)

    return jsonify(response.json()), response.status_code

if __name__ == '__main__':
    app.run(debug=True)
