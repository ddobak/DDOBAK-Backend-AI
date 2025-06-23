import json
import boto3

bedrock = boto3.client("bedrock-runtime")  # 필요한 경우 'runtime'으로 다르게 설정됨

def lambda_handler(event, context):
    # event에서 contractTexts 추출
    contract_texts = event["contractTexts"]  # list of strings
    
    # 모든 페이지의 텍스트를 합침
    full_text = "\n---\n".join(
        f"Page {idx + 1}:\n{text}" for idx, text in enumerate(contract_texts)
    )
    
    # 예시: Anthropic Claude 호출
    # response = bedrock.invoke_model(
    #     modelId="anthropic.claude-v2",
    #     contentType="application/json",
    #     accept="application/json",
    #     body=json.dumps({
    #         "prompt": f"다음 계약서를 요약하고 중요한 조항을 알려줘:\n\n{full_text}",
    #         "max_tokens": 1024,
    #         "temperature": 0.5,
    #     })
    # )

    # 샘플 결과 데이터 구성
    output = {
        "success": True,
        "message": "",
        "data": {
            "summary": "본 계약은 근무계약이며, 계약 기간은 1년이다.",
            "ddobakCommentary": {
                "overallComment": "또박이 한마디",
                "warningComment": "주의 사항 요약",
                "advice": "또박이의 조언"
            },
            "toxics": [
                {
                    "title": "근무 장소 및 직무 변경 조항",
                    "clause": "을은 사전 통보 없이 계약을 해지할 수 있다.",
                    "reason": "사용자에게 일방적인 해지 권한이 있음",
                    "reasonReference": "위의 몇조 몇항에 따라 위가 어떻게...",
                    "warnLevel": 3
                }
            ]
        }
    }

    return output