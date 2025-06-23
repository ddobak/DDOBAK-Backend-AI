import json
import boto3
import re
import os
from dotenv import load_dotenv

# 코드랑 같은 디렉터리에 .env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

s3 = boto3.client("s3")

def extract_page_number(s3_key):
    match = re.search(r"/(\d+)\.jpg$", s3_key)
    return match.group(1) if match else "unknown"

def lambda_handler(event, context=None):
    bucket = os.environ["S3_BUCKET"]
    key = event["s3Key"]
    
    page_num = event["pageIdx"]
    
    # Mock 데이터 반환
    return {
        "success": True,
        "message": "",
        "data": {
            "page_idx": page_num,
            "html_entire": "<html><body><h1>전체 HTML Mock 데이터</h1><table><tr><td>테스트 데이터</td></tr></table></body></html>",
            "html_array": [
                {
                    "category": "table",
                    "html": "<table><tr><td>테스트 테이블</td></tr></table>",
                    "id": "table_1"
                },
                {
                    "category": "text",
                    "html": "<p>테스트 텍스트 블록</p>",
                    "id": "text_1"
                }
            ]
        }
    }