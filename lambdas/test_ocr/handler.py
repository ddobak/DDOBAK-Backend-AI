import json
import boto3
import re

s3 = boto3.client("s3")

def extract_page_number(s3_key):
    match = re.search(r"/(\d+)\.jpg$", s3_key)
    return match.group(1) if match else "unknown"

def lambda_handler(event, context):
    contract_id = event["contractId"]
    s3_key = event["s3Key"]

    bucket_name = "your-bucket-name"
    
    # 실제 OCR을 수행할 부분 (여기선 단순 mock)
    # s3_object = s3.get_object(Bucket=bucket_name, Key=s3_key)
    # image_bytes = s3_object["Body"].read()
    
    # TODO: Replace with actual OCR (Textract, external API, etc.)
    ocr_text = f"OCR result of {s3_key}"

    return {
        "page": 1,
        "text": ocr_text,
        "s3Key": s3_key
    }