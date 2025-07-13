import json
import boto3
import os
from json_repair import repair_json
from dotenv import load_dotenv

# 지식 기반 ID 환경 변수 설정
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))
KNOWLEDGE_BASE_ID = os.getenv("KNOWLEDGE_BASE_ID")

# bedrock-runtime 클라이언트 초기화
bedrock_runtime = boto3.client(service_name="bedrock-runtime", region_name="ap-northeast-2")
# bedrock-agent-runtime 클라이언트 초기화 (Knowledge Base용)
bedrock_agent_runtime = boto3.client(service_name="bedrock-agent-runtime", region_name="ap-northeast-2")


def retrieve_knowledge_base(query, model_id):
    """지식 기반에서 관련 문서를 검색하는 함수"""
    try:
        print(f"[RETRIEVE] 지식 기반 검색 시작 - Model: {model_id}")
        print(f"[RETRIEVE] 검색 쿼리: {query[:200]}...")
        
        response = bedrock_agent_runtime.retrieve(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            retrievalQuery={
                "text": query
            },
            retrievalConfiguration={
                "vectorSearchConfiguration": {
                    "numberOfResults": 5  # 검색 결과 개수 조정 가능
                }
            }
        )
        
        # 전체 검색 응답 로깅
        print(f"[RETRIEVE] Bedrock 검색 응답 전문: {json.dumps(response, ensure_ascii=False, indent=2)}")
        
        # 검색 결과 처리
        retrieval_results = response.get("retrievalResults", [])
        
        if not retrieval_results:
            print("[RETRIEVE] 검색 결과가 없습니다.")
            return None
            
        print(f"[RETRIEVE] 검색 결과 개수: {len(retrieval_results)}")
        
        # 검색 결과를 텍스트로 변환
        knowledge_context = ""
        for idx, result in enumerate(retrieval_results):
            content = result.get("content", {}).get("text", "")
            location = result.get("location", {})
            
            knowledge_context += f"\n--- 참고 문서 {idx + 1} ---\n"
            knowledge_context += f"출처: {location.get('s3Location', {}).get('uri', 'Unknown')}\n"
            knowledge_context += f"내용: {content}\n"
        
        print(f"[RETRIEVE] 지식 기반 검색 성공 - 참고 문서 {len(retrieval_results)}개 발견")
        return {
            "success": True,
            "results": retrieval_results,
            "context": knowledge_context,
            "count": len(retrieval_results)
        }
        
    except Exception as e:
        print(f"[RETRIEVE] 지식 기반 검색 오류: {str(e)}")
        print(f"[RETRIEVE] 오류 유형: {type(e).__name__}")
        return None


def invoke_with_context(prompt, knowledge_context, model_id, source_type):
    """컨텍스트를 포함하여 모델에 요청하는 함수"""
    try:
        print(f"[INVOKE] 모델 요청 시작 - 소스: {source_type}, Model: {model_id}")
        
        # 지식 기반 검색 결과가 있으면 프롬프트에 포함
        if knowledge_context:
            enhanced_prompt = f"""다음은 관련 법률 및 판례 정보입니다. 이 정보를 참고하여 계약서를 분석해주세요:

{knowledge_context}

---

{prompt}"""
            print(f"[INVOKE] 지식 기반 컨텍스트 포함하여 요청")
        else:
            enhanced_prompt = prompt
            print(f"[INVOKE] 일반 지식으로 요청")
        
        # 일반 InvokeModel API 사용
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 4000,
            "messages": [
                {
                    "role": "user",
                    "content": enhanced_prompt
                }
            ]
        }
        
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps(body, ensure_ascii=False)
        )
        
        # 응답 파싱
        response_body = json.loads(response['body'].read())
        
        # 전체 응답 로깅
        print(f"[INVOKE] Bedrock 응답 전문: {json.dumps(response_body, ensure_ascii=False, indent=2)}")
        
        answer = response_body["content"][0]["text"]
        
        print(f"[INVOKE] 성공적으로 응답을 생성했습니다 - 소스: {source_type}")
        return {
            "success": True,
            "source": source_type,
            "response": response_body,
            "answer": answer
        }
        
    except Exception as e:
        print(f"[INVOKE] 모델 요청 오류: {str(e)}")
        print(f"[INVOKE] 오류 유형: {type(e).__name__}")
        raise e


def extract_toxic_clauses(contract_id, analysis_id, contract_text):
    """독소조항 추출 함수 - 지식 기반 검색 후 컨텍스트 포함하여 요청"""
    # prompt.txt 파일 읽기
    current_dir = os.path.dirname(os.path.abspath(__file__))
    prompt_file_path = os.path.join(current_dir, "prompt.txt")

    with open(prompt_file_path, "r", encoding="utf-8") as f:
        prompt_template = f.read()

    # contract_text를 템플릿에 삽입
    prompt = prompt_template.replace("{{contract_document}}", contract_text)

    model_id = "anthropic.claude-3-5-sonnet-20240620-v1:0"

    print(f"[MAIN] 계약서 분석 시작 - Contract ID: {contract_id}, Analysis ID: {analysis_id}")
    
    # 1단계: 지식 기반에서 관련 문서 검색
    knowledge_result = retrieve_knowledge_base(prompt, model_id)
    
    if knowledge_result is not None:
        # 지식 기반 검색 성공 - 컨텍스트 포함하여 요청
        print(f"[MAIN] 지식 기반 검색 성공 - 참고 문서 {knowledge_result['count']}개")
        invoke_result = invoke_with_context(prompt, knowledge_result["context"], model_id, "knowledge_base")
        source_type = "knowledge_base"
        citations_count = knowledge_result["count"]
    else:
        # 지식 기반 검색 실패 - 일반 지식으로 요청
        print(f"[MAIN] 지식 기반 검색 실패 - 일반 지식으로 요청")
        invoke_result = invoke_with_context(prompt, None, model_id, "general_request")
        source_type = "general_request"
        citations_count = 0

    answer = invoke_result["answer"]

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

        # 필수 필드 보완
        if not parsed_result.get("originContent"):
            parsed_result["originContent"] = contract_text

        if not parsed_result.get("title"):
            parsed_result["title"] = "계약서"

        print(f"[MAIN] JSON 파싱 성공 - 소스: {source_type}, 참고 문서: {citations_count}개")
        
        return {
            "status": "success",
            "model_used": model_id,
            "source_type": source_type,
            "citations_count": citations_count,
            "data": {
                "contractId": contract_id,
                "analysisResult": parsed_result
            }
        }

    except Exception as e:
        print(f"[MAIN] JSON 파싱 실패: {str(e)}")
        # JSON 파싱 실패 시 원본 응답 반환
        return {
            "status": "partial_success",
            "model_used": model_id,
            "source_type": source_type,
            "citations_count": citations_count,
            "raw_response": answer,
            "parse_error": str(e),
            "data": {
                "contractId": contract_id,
                "analysisId": analysis_id,
                "title": "분석 불가능한 계약서",
                "originContent": contract_text,
                "summary": "응답 파싱 중 오류가 발생했습니다.",
                "ddobakCommentary": {
                    "overallComment": "분석을 완료했으나 구조화된 응답 생성에 실패했습니다.",
                    "warningComment": "원본 응답을 확인해주세요.",
                    "advice": "다시 시도해보시거나 관리자에게 문의하세요."
                },
                "toxicCount": 0,
                "toxics": [],
            },
        }


def lambda_handler(event, context):
    """Lambda 핸들러 함수"""
    try:
        contract_id = event["contractId"]
        analysis_id = event["analysisId"]
        contract_text = event["contractTexts"]

        full_text = "\n---\n".join(f"Page {idx + 1}:\n{text}" for idx, text in enumerate(contract_text))

        print(f"[LAMBDA] Lambda 실행 시작 - Contract ID: {contract_id}, Analysis ID: {analysis_id}")
        
        # 독소조항 추출 수행
        result = extract_toxic_clauses(contract_id, analysis_id, full_text)

        response = {
            "success": True,
            "message": "",
            "data": {
                "contractId": contract_id,
                "analysisId": analysis_id,
                "analysisResult": result["data"],
                "metadata": {
                    "source_type": result.get("source_type", "unknown"),
                    "citations_count": result.get("citations_count", 0),
                    "model_used": result.get("model_used", "unknown")
                }
            }
        }

        print(f"[LAMBDA] Lambda 실행 완료 - 소스: {result.get('source_type', 'unknown')}")
        print(f"[LAMBDA] 최종 응답: {json.dumps(response, ensure_ascii=False, indent=2)}")

        return response

    except Exception as e:
        print(f"[LAMBDA] Lambda 실행 중 오류 발생: {str(e)}")
        print(f"[LAMBDA] 오류 유형: {type(e).__name__}")

        # 오류 발생 시에도 기본 구조 유지
        error_response = {
            "success": False,
            "message": str(e),
            "data": {
                "contractId": contract_id if 'contract_id' in locals() else "unknown",
                "analysisId": analysis_id if 'analysis_id' in locals() else "unknown",
                "analysisResult": {
                    "title": "분석 오류 계약서",
                    "originContent": full_text if 'full_text' in locals() else "",
                    "summary": f"분석 중 오류가 발생했습니다. {str(e)}",
                    "ddobakCommentary": {
                        "overallComment": "시스템 오류로 인해 분석을 완료할 수 없습니다.",
                        "warningComment": "서비스 관리자에게 문의하시기 바랍니다.",
                        "advice": "잠시 후 다시 시도해보세요."
                    },
                    "toxicCount": 0,
                    "toxics": [],
                },
                "metadata": {
                    "source_type": "error",
                    "citations_count": 0,
                    "model_used": "unknown"
                }
            }
        }

        print(f"[LAMBDA] 오류 응답: {json.dumps(error_response, ensure_ascii=False, indent=2)}")
        return error_response
