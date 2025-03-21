import os
from app import *
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
    # print("Request Headers:", request.headers)
    # print("Request Content-Type:", request.content_type)
    # print("Request Form:", request.form)
    # print("Request Files:", request.files)
    
    
    token = request.headers.get('Authorization')

    if not token:
        return jsonify({"error": "No token provided"}), 401
    
    file = request.files.get('file')
    if not file:
        return jsonify({"error": "No file provided"}), 400

    user_id = request.form.get("user_id")  
    file = request.files.get("file")  

    if not user_id or not file:
        return jsonify({"message": "Missing required parameters"}), 400
    
    response = upload_file(file, user_id)
    return jsonify({"message": "File uploaded successfully"}), 200

@app.route('/fetch', methods=['GET'])
def fetch():
    token = request.headers.get('Authorization')

    if not token:
        return jsonify({"error": "No token provided"}), 401
    
    file_id = request.args.get('file_id')
    user_id = request.args.get('user_id')

    if not file_id or not user_id:
        return jsonify({"error": "Missing required parameters"}), 400

    params = {
        "FileId": file_id,
        "UserId": user_id
    }

    # Call fetch_file directly
    response = fetch_file(params)

    return jsonify(response), response["statusCode"]

if __name__ == '__main__':
    app.run(debug=True)
