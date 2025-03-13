import json
import boto3
import base64
import uuid
import os
from datetime import datetime

# AWS Clients
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
firehose_client = boto3.client('firehose', region_name='us-east-1')

TABLE_NAME = os.getenv('DYNAMODB_TABLE', 'S3FileMetadata')
FIREHOSE_STREAM = os.getenv('FIREHOSE_STREAM', 'your-firehose-stream-name')
S3_BUCKET = os.getenv('S3_BUCKET', 'your-s3-bucket-name')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    try:
        http_method = event["httpMethod"]

        if http_method == "POST":
            return upload_file(json.loads(event["body"]))
        elif http_method == "GET":
            return fetch_file(event["queryStringParameters"])
        else:
            return generate_response(400, "Invalid action")
    except Exception as e:
        return generate_response(500, f"Internal Server Error: {str(e)}")

def upload_file(body):
    """
    Uploads file to S3 and stores metadata in DynamoDB & Kinesis.
    """
    file_name = body.get("file_name")
    user_id = body.get("user_id")
    file_content = body.get("file_content")  # Base64 encoded

    if not file_name or not user_id or not file_content:
        return generate_response(400, "Missing required parameters")

    file_id = str(uuid.uuid4())
    file_key = f"{user_id}/{file_id}/{file_name}"

    metadata = {
        "file_id": file_id,
        "file_name": file_name,
        "user_id": user_id,
        "timestamp": datetime.utcnow().isoformat(),
        "file_key": file_key
    }
    try: 
        firehose_client.put_record(
            DeliveryStreamName= "cloudbox-stream",
            Record={
                'Data': json.dumps(metadata) + "\n"  # Firehose expects a newline character
            }
        )
    except Exception as e:
        return generate_response(500, f"Firehose Stream Failed: {str(e)}")

    table.put_item(Item=metadata)

    decoded_file = base64.b64decode(file_content)
    try:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=file_key,
            Body=decoded_file,
            ContentType="application/octet-stream"
        )
    except Exception as e:
        return generate_response(500, f"S3 Upload Failed: {str(e)}")
    
    return generate_response(200, f"File {file_name} uploaded successfully")

def fetch_file(params):
    """
    Fetches file metadata from DynamoDB and generates a pre-signed URL.
    """
    file_id = params.get("FileId")
    user_id = params.get("UserId")

    if not file_id or not user_id:
        return generate_response(400, "Missing required parameters")

    response = table.get_item(Key={"file_id": file_id, "user_id": user_id})

    if "Item" not in response:
        return generate_response(404, "File not found")

    file_metadata = response["Item"]
    file_key = file_metadata["file_key"]

    presigned_url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": S3_BUCKET, "Key": file_key},
        ExpiresIn=3600
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
