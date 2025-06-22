import json
import boto3
import os

# Bedrock Runtime client - 서울 지역 사용
bedrock_runtime = boto3.client(service_name="bedrock-runtime", region_name="ap-northeast-2")


def extract_toxic_clauses(contract_text):
    """
    계약서 텍스트에서 독소조항을 추출하고 분석하는 함수

    Args:
        contract_text (str): 계약서 전문 텍스트

    Returns:
        dict: 독소조항 분석 결과 (모바일 앱 UI 형식)
    """
    # Claude 3를 위한 독소조항 추출 프롬프트 (UI 구조에 맞게 수정)
    prompt = f"""
다음 계약서 내용을 분석하여 독소조항(불공정 조항)을 추출하고 분석해주세요.

<contract>
{contract_text}
</contract>

다음 기준으로 분석하여 JSON 형식으로 응답해주세요:

1. **독소조항 식별**: 
   - 일방적으로 불리한 조항
   - 과도한 책임 부담 조항
   - 부당한 손해배상 조항
   - 계약 해지 관련 불공정 조항
   - 개인정보 과도 수집/활용 조항

2. **위험도 평가**: 각 조항을 HIGH/MEDIUM/LOW로 분류

3. **응답 형식**: 반드시 다음 JSON 구조로 응답하세요.

```json
{{
  "summary": "계약서의 주요 내용과 발견된 독소조항에 대한 간략한 요약 (2-3문장)",
  "ddobakCommentary": {{
    "overallComment": "전체적인 계약서 평가 (한 문장으로)",
    "warningComment": "가장 주의해야 할 사항들 요약 (2-3문장)",
    "advice": "계약자를 위한 구체적인 조언 (2-3문장)"
  }},
  "toxicCount": 발견된_독소조항_개수,
  "toxics": [
    {{
      "title": "독소조항의 핵심 내용을 한 줄로 표현한 제목",
      "clause": "해당 독소조항의 원문",
      "reason": "왜 이 조항이 문제가 되는지 구체적인 이유",
      "warnLevel": "HIGH|MEDIUM|LOW"
    }}
  ]
}}
```

주의사항:
- originContent에는 입력받은 계약서 전문을 그대로 포함
- summary는 일반인이 이해하기 쉽게 작성
- 각 독소조항의 title은 사용자가 한눈에 파악할 수 있도록 간결하게
- reason은 법적 근거나 실제 피해 사례를 포함하여 구체적으로 작성
- warnLevel은 해당 조항이 계약자에게 미칠 수 있는 피해 정도를 기준으로 판단
"""

    # Claude 3.5 Sonnet 모델 사용 (고성능 분석)
    model_id = "anthropic.claude-3-5-sonnet-20240620-v1:0"

    body = json.dumps(
        {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 4000,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,  # 일관성을 위해 낮은 온도 설정
            "top_p": 0.9,
        }
    )

    try:
        response = bedrock_runtime.invoke_model(body=body, modelId=model_id, accept="application/json", contentType="application/json")

        response_body = json.loads(response.get("body").read())
        ai_response = response_body["content"][0]["text"]

        # Claude 응답에서 JSON 부분만 추출
        try:
            # ```json ... ``` 형태에서 JSON 부분만 추출
            if "```json" in ai_response:
                json_start = ai_response.find("```json") + 7
                json_end = ai_response.find("```", json_start)
                json_str = ai_response[json_start:json_end].strip()
            else:
                # JSON이 바로 시작하는 경우
                json_str = ai_response.strip()

            # JSON 파싱 시도
            parsed_result = json.loads(json_str)

            # originContent 필드가 비어있으면 원본 텍스트로 채우기
            if not parsed_result.get("originContent"):
                parsed_result["originContent"] = contract_text

            return {"status": "success", "model_used": model_id, "data": parsed_result}

        except (json.JSONDecodeError, KeyError) as e:
            # JSON 파싱 실패 시 원본 응답 반환
            return {
                "status": "partial_success",
                "model_used": model_id,
                "raw_response": ai_response,
                "parse_error": str(e),
                "data": {
                    "originContent": contract_text,
                    "summary": "응답 파싱 중 오류가 발생했습니다.",
                    "ddobakCommentary": {"overallComment": "분석을 완료했으나 구조화된 응답 생성에 실패했습니다.", "warningComment": "원본 응답을 확인해주세요.", "advice": "다시 시도해보시거나 관리자에게 문의하세요."},
                    "toxicCount": 0,
                    "toxics": [],
                },
            }

    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "model_used": model_id,
            "data": {
                "originContent": contract_text,
                "summary": "분석 중 오류가 발생했습니다.",
                "ddobakCommentary": {"overallComment": "시스템 오류로 인해 분석을 완료할 수 없습니다.", "warningComment": "서비스 관리자에게 문의하시기 바랍니다.", "advice": "잠시 후 다시 시도해보세요."},
                "toxicCount": 0,
                "toxics": [],
            },
        }


def lambda_handler(event, context):
    """
    Lambda 핸들러 - S3 이벤트와 API Gateway 양쪽 모두 지원

    Args:
        event: Lambda 이벤트 (S3 이벤트 또는 API Gateway 이벤트)
        context: Lambda 컨텍스트

    Returns:
        dict: 독소조항 분석 결과 (모바일 앱 UI 형식)
    """

    try:
        contract_text = ""

        # API Gateway 이벤트인지 확인 (OCR Lambda 결과 직접 전달)
        if "body" in event:
            print("Processing API Gateway event...")
            if isinstance(event["body"], str):
                body = json.loads(event["body"])
            else:
                body = event["body"]

            contract_text = body.get("contract_text", "")

        # 직접 함수 호출 (테스트용)
        elif "contract_text" in event:
            print("Processing direct function call...")
            contract_text = event["contract_text"]

        else:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
                "body": json.dumps({"error": "Invalid event format. Expected API Gateway event or direct contract_text."}, ensure_ascii=False),
            }

        if not contract_text.strip():
            return {"statusCode": 400, "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"}, "body": json.dumps({"error": "Contract text is empty."}, ensure_ascii=False)}

        # 독소조항 추출 수행
        result = extract_toxic_clauses(contract_text)

        return {"statusCode": 200, "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"}, "body": json.dumps(result, ensure_ascii=False)}

    except Exception as e:
        print(f"Error processing contract: {str(e)}")
        return {"statusCode": 500, "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"}, "body": json.dumps({"error": "Internal server error", "details": str(e)}, ensure_ascii=False)}
