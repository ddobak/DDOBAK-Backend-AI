import json
import boto3
import os
from json_repair import repair_json

bedrock_runtime = boto3.client(service_name="bedrock-runtime", region_name="ap-northeast-2")


def extract_toxic_clauses(contract_id, analysis_id, contract_text):
    # prompt.txt 파일 읽기
    current_dir = os.path.dirname(os.path.abspath(__file__))
    prompt_file_path = os.path.join(current_dir, "prompt.txt")
    
    with open(prompt_file_path, 'r', encoding='utf-8') as f:
        prompt_template = f.read()
    
    # contract_text를 템플릿에 삽입
    prompt = prompt_template.replace("{{contract_document}}", contract_text)

    model_id = "anthropic.claude-3-5-sonnet-20240620-v1:0"

    body = json.dumps(
        {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 4000,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "top_p": 0.9,
        }
    )

    try:
        response = bedrock_runtime.invoke_model(body=body, modelId=model_id, accept="application/json", contentType="application/json")

        response_body = json.loads(response.get("body").read())
        answer = response_body["content"][0]["text"]

        try:
            # JSON 블록에서 JSON 추출
            if "```json" in answer:
                json_start = answer.find("```json") + 7
                json_end = answer.find("```", json_start)
                json_str = answer[json_start:json_end].strip()
            else:
                # JSON이 바로 시작하는 경우
                json_str = answer.strip()

            # json-repair를 사용하여 JSON 복구 및 파싱
            repaired_json = repair_json(json_str)
            parsed_result = json.loads(repaired_json)

            if not parsed_result.get("originContent"):
                parsed_result["originContent"] = contract_text

            return {"status": "success", "model_used": model_id, "data": {
                "contractId": contract_id,
                "analysisResult": parsed_result
            }}

        except Exception as e:
            # JSON 파싱 실패 시 원본 응답 반환
            return {
                "status": "partial_success",
                "model_used": model_id,
                "raw_response": answer,
                "parse_error": str(e),
                "data": {
                    "contractId": contract_id,
                    "analysisId": analysis_id,
                    "originContent": contract_text,
                    "summary": "응답 파싱 중 오류가 발생했습니다.",
                    "ddobakCommentary": {"overallComment": "분석을 완료했으나 구조화된 응답 생성에 실패했습니다.", "warningComment": "원본 응답을 확인해주세요.", "advice": "다시 시도해보시거나 관리자에게 문의하세요."},
                    "toxicCount": 0,
                    "toxics": [],
                },
            }

    except Exception as e:
        print(f"Error processing contract: {str(e)}")
        return {
            "status": "error",
            "error": str(e),
            "model_used": model_id,
            "data": {
                "contractId": contract_id,
                "analysisId": analysis_id,
                "originContent": contract_text,
                "summary": f"분석 중 오류가 발생했습니다. {str(e)}",
                "ddobakCommentary": {"overallComment": "시스템 오류로 인해 분석을 완료할 수 없습니다.", "warningComment": "서비스 관리자에게 문의하시기 바랍니다.", "advice": "잠시 후 다시 시도해보세요."},
                "toxicCount": 0,
                "toxics": [],
            },
        }


def lambda_handler(event, context):
    try:
        contract_id = event["contractId"]
        analysis_id = event["analysisId"]
        contract_text = event["contractTexts"]

        full_text = "\n---\n".join(
            f"Page {idx + 1}:\n{text}" for idx, text in enumerate(contract_text)
        )

        # 독소조항 추출 수행
        result = extract_toxic_clauses(contract_id, analysis_id, full_text)

        response = {
            "success": True,
            "message": "",
            "data": {
                "contractId": contract_id,
                "analysisId": analysis_id,
                "analysisResult": result['data']
            }
        }
        
        # 최종 반환값 로그 출력
        print(f"Lambda response: {json.dumps(response, ensure_ascii=False, indent=2)}")
        
        return response

    except Exception as e:
        print(f"Error processing contract: {str(e)}")
        
        error_response = {
            "success": False,
            "message": str(e),
            "data": {
                "contractId": contract_id,
                "analysisId": analysis_id,
                "analysisResult": result['data']
            }
        }
        
        # 에러 응답도 로그 출력
        print(f"Lambda error response: {json.dumps(error_response, ensure_ascii=False, indent=2)}")
        
        return error_response
