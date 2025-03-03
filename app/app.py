import os
import requests
import base64
from flask import Flask, request, session, jsonify

app = Flask(__name__)
app.secret_key = os.urandom(24)

LAMBDA_UPLOAD_URL = os.getenv(LAMBDA_UPLOAD_URL)

@app.route('/upload', methods=['POST'])
def upload():
    user = session.get('user')
    if not user:
        return jsonify({"error": "Unauthorized"}), 401

    file = request.files.get('file')
    if not file:
        return jsonify({"error": "No file provided"}), 400

    file_content = file.read()
    encoded_file = base64.b64encode(file_content).decode('utf-8')

    payload = {
        "file_name": file.filename,
        "user_id": user["email"],
        "file_content": encoded_file
    }

    headers = {"Authorization": f"Bearer {user['token']}"}
    
    response = requests.post(LAMBDA_UPLOAD_URL, json=payload, headers=headers)

    return jsonify(response.json()), response.status_code

if __name__ == '__main__':
    app.run(debug=True)
