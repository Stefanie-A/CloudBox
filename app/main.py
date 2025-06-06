import os
from app import *  # Import all necessary functions
import requests
import datetime
from flask import Flask, request, jsonify, session
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = os.urandom(24)

@app.route('/home')
def home():
    return jsonify({"message": "Welcome to CloudBox!"})

@app.route('/upload', methods=['POST'])
def upload():
    user_id = request.form.get("user_id")
    file = request.files.get('file')
    if not file or not user_id:
        return jsonify({"error": "Missing file or user id"}), 400

    # Validate file type and size
    allowed_extensions = {'png', 'jpg', 'jpeg', 'gif', 'pdf'}
    max_file_size = 5 * 1024 * 1024  # 5 MB

    file_extension = file.filename.rsplit('.', 1)[-1].lower()
    if file_extension not in allowed_extensions:
        return jsonify({"error": "Invalid file type"}), 400

    if len(file.read()) > max_file_size:
        return jsonify({"error": "File size exceeds the limit"}), 400

    file.seek(0)  # Reset file pointer after reading size
    
    return jsonify({
        "message": "File uploaded successfully",
        "file_name": file.filename,
        "user_id": user_id
    }), 200
    return jsonify({"message": "File uploaded successfully"}), 200

@app.route('/fetch', methods=['GET'])
def fetch():
    """API endpoint to fetch file metadata."""
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({"error": "No token provided"}), 401

    file_id = request.args.get('file_id')
    user_id = request.args.get('user_id', '').strip()

    if not file_id or not user_id:
        return jsonify({"error": "Missing required parameters"}), 400

    print(f"DEBUG: Fetching file with file_id={file_id}, user_id={user_id}")

    response = fetch_file(file_id, user_id)

    return jsonify(response["body"]), response["statusCode"]


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
