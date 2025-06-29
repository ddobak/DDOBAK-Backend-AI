import boto3
import requests
import os
import io
from dotenv import load_dotenv

# 코드랑 같은 디렉터리에 .env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

s3 = boto3.client("s3")

def lambda_handler(event, context):
    bucket = os.environ["S3_BUCKET"]
    key = event["s3Key"]
    page_num = event["pageIdx"]

    try:
        # Download the image from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        image_content = response["Body"].read()

        # Create file-like object from bytes
        image_file = io.BytesIO(image_content)
        filename = key.split("/")[-1]

        # Determine content type from file extension
        file_ext = filename.lower().split(".")[-1]
        if file_ext in ["jpeg", "png"]:
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


        html_entire = result["content"]["html"]
        html_array = [
            {
                "category": e["category"],
                "html": e["content"]["html"],
                "id": e["id"]
            } for e in result["elements"]
        ]
        if result:
            data = {
                "page_idx": page_num,
                "html_entire": html_entire,
                "html_array": html_array
            }

        return {
            "success": True,
            "message": "",
            "data": data
        }

    except Exception as e:
        print(e)
        return {
            "success": False,
            "message": str(e),
            "data": {}
        }
