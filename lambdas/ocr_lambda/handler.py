"""
OCR Lambda Handler
Simple sample lambda function for testing
"""

import json
import asyncio
from typing import Dict, Any


async def async_process() -> Dict[str, Any]:
    """
    비동기 처리 함수 - 기존과 동일한 샘플 응답
    
    Returns:
        샘플 응답 데이터
    """
    # 비동기 처리 시뮬레이션
    await asyncio.sleep(0.1)
    
    return {
        'status': 'success',
        'data': {
            'content': 'this is sample response async'
        }
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda 핸들러 함수 - 비동기 처리가 가능한 샘플 응답 반환
    
    Args:
        event: Lambda 이벤트 데이터
        context: Lambda 컨텍스트 객체
        
    Returns:
        샘플 응답
    """
    # 비동기 함수 실행
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    try:
        result = loop.run_until_complete(async_process())
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result, ensure_ascii=False)
        }
    finally:
        loop.close()


if __name__ == "__main__":
    """
    로컬 테스트용 구간
    
    사용법:
        poetry run python lambdas/ocr_lambda/handler.py

    테스트할 로직, 함수 등을 넣어서 테스트
    """