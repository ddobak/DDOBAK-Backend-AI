import boto3
import requests
import os
import io
from dotenv import load_dotenv

print("Loading function")

# 현재 디렉터리의 .env 파일 로드
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

s3 = boto3.client("s3", region_name="ap-northeast-2")


def lambda_handler(event, context):
    bucket = "ddobak-test"
    key = event["s3Key"]

    try:
        # Download the image from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        image_content = response["Body"].read()

        # Create file-like object from bytes
        image_file = io.BytesIO(image_content)
        filename = key.split("/")[-1]

        # Determine content type from file extension
        file_ext = filename.lower().split(".")[-1]
        page_num = filename.lower().split(".")[0]
        if file_ext in ["jpeg", "png", "jpg"]:
            content_type = f"image/{file_ext}"
        else:
            return {"error": f"Unsupported file type: {file_ext}. Only jpg/jpeg files are supported."}

        # Process with Upstage OCR
        api_key = os.environ["UPSTAGE_API_KEY"]
        url = "https://api.upstage.ai/v1/document-digitization"
        headers = {"Authorization": f"Bearer {api_key}"}
        files = {"document": (filename, image_file, content_type)}
        data = {"ocr": "force", "base64_encoding": "['table']", "model": "document-parse"}

        response = requests.post(url, headers=headers, files=files, data=data)
        result = response.json()

        return {
            "page": page_num,
            "text": result['content']['html'],
            "s3Key": key
        }

    except Exception as e:
        print(e)
        return {"error": str(e)}
