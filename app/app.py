import json
import boto3
import uuid
import os
from datetime import datetime

# AWS Clients
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
firehose_client = boto3.client('firehose', region_name='us-east-1')

TABLE_NAME = os.getenv('DYNAMODB_TABLE', 'S3FileMetadata')
FIREHOSE_STREAM = os.getenv('FIREHOSE_STREAM', 'cloudbox-stream')
S3_BUCKET = os.getenv('S3_BUCKET', 'cloudbox-bucket2825')
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

def upload_file(file, user_id):
    """
    Uploads file to S3 and stores metadata in DynamoDB & Kinesis.
    """
    file_id = str(uuid.uuid4())
    file_name = file.filename
    file_key = f"{user_id}/{file_id}/{file_name}"

    if not file or not user_id:
        return generate_response(400, "Missing required parameters")

    try:
        s3_client.upload_fileobj(file, S3_BUCKET, file_key)
    except Exception as e:
        return generate_response(500, f"S3 Upload Failed: {str(e)}")

    # Generate Pre-signed URL
    presigned_url = s3_client.generate_presigned_url(
        'put_object',
        Params={'Bucket': S3_BUCKET, 'Key': file_key},
        ExpiresIn=3600
    )

    metadata = {
        "user_id": user_id,
        "file_id": file_id,
        "file_name": file_name,
        "file_key": file_key,
        'pre_signed_url': presigned_url,
        "timestamp": datetime.utcnow().isoformat(),
        
    }
    try: 
        firehose_client.put_record(
            DeliveryStreamName= FIREHOSE_STREAM,
            Record={
                'Data': json.dumps(metadata) + "\n" 
            }
        )
    except Exception as e:
        return generate_response(500, f"Firehose Stream Failed: {str(e)}")
    try:
        table.put_item(Item=metadata)
    except Exception as e:
        return generate_response(500, f"DynamoDB Put Failed")
    
    
    return generate_response(200, f"File {file_name} uploaded successfully")

def fetch_file(file_id, user_id):
    # Ensure both file_id and user_id are provided
    try:
        response = table.get_item(Key={"file_id": file_id, "user_id": user_id})

        # Log DynamoDB response
        print("DEBUG: DynamoDB Response:", json.dumps(response, indent=4))

        item = response.get("Item")
        if not item:
            return {"statusCode": 404, "body": {"message": "File not found"}}

        return {"statusCode": 200, "body": item}

    except Exception as e:
        print("DEBUG: Error fetching from DynamoDB:", str(e))
        return {"statusCode": 500, "body": {"error": str(e)}}

def generate_response(status_code, message):
    """
    Helper function to generate API response.
    """
    return {
        "statusCode": status_code,
        "body": json.dumps({"message": message})
    }
