import json
import boto3
import base64
import os
import uuid
from datetime import datetime

# Initialize AWS clients
s3_client = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
kinesis_client = boto3.client("kinesis")

# Load environment variables
DYNAMODB_TABLE = os.getenv("DYNAMODB_TABLE")
S3_BUCKET = os.getenv("S3_BUCKET")
KINESIS_STREAM = os.getenv("KINESIS_STREAM")

table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    """
    Handles API requests to upload or fetch files.
    """
    try:
        body = json.loads(event['body'])
        action = body.get("action")

        if action == "upload":
            return upload_file(body)
        elif action == "fetch":
            return fetch_file(body)
        else:
            return generate_response(400, "Invalid action")
    except Exception as e:
        print(f"Error: {str(e)}")
        return generate_response(500, f"Internal Server Error: {str(e)}")

def upload_file(body):
    """
    Upload file metadata to Kinesis before storing the file in S3.
    """
    file_name = body.get("file_name")
    user_id = body.get("user_id")
    file_content = body.get("file_content")  # Base64 encoded

    if not file_name or not user_id or not file_content:
        return generate_response(400, "Missing required parameters")

    # Generate unique file key
    file_id = str(uuid.uuid4())
    file_key = f"{user_id}/{file_id}/{file_name}"

    # Prepare metadata for Kinesis
    metadata = {
        "file_id": file_id,
        "file_name": file_name,
        "user_id": user_id,
        "timestamp": datetime.utcnow().isoformat()
    }

    # Send metadata to Kinesis
    kinesis_client.put_record(
        StreamName=KINESIS_STREAM,
        Data=json.dumps(metadata),
        PartitionKey=user_id
    )

    # Upload file to S3
    decoded_file = base64.b64decode(file_content)
    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=file_key,
        Body=decoded_file,
        ContentType="application/octet-stream"
    )

    return generate_response(200, f"File {file_name} uploaded successfully")

def fetch_file(body):
    """
    Fetch file metadata from DynamoDB and generate a pre-signed URL.
    """
    file_name = body.get("file_name")
    user_id = body.get("user_id")

    if not file_name or not user_id:
        return generate_response(400, "Missing required parameters")

    # Query DynamoDB
    response = table.get_item(Key={"file_name": file_name, "user_id": user_id})

    if "Item" not in response:
        return generate_response(404, "File not found")

    file_metadata = response["Item"]
    file_key = f"{user_id}/{file_metadata['file_id']}/{file_name}"

    # Generate a pre-signed URL for file download
    presigned_url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": S3_BUCKET, "Key": file_key},
        ExpiresIn=3600  # 1-hour expiry
    )

    return generate_response(200, {"presigned_url": presigned_url})

def generate_response(status_code, message):
    """
    Helper function to generate API response.
    """
    return {
        "statusCode": status_code,
        "body": json.dumps({"message": message})
    }
