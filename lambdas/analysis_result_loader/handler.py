import os
import json
import uuid
import psycopg2
from datetime import datetime
from dotenv import load_dotenv

# 코드랑 같은 디렉터리에 .env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

def get_db_connection():
    """PostgreSQL 데이터베이스 연결을 반환합니다."""
    try:
        connection = psycopg2.connect(
            host=os.getenv('DB_HOST'),
            port=os.getenv('DB_PORT'),
            database=os.getenv('DB_NAME'),
            user=os.getenv('DB_USERNAME'),
            password=os.getenv('DB_PASSWORD')
        )
        return connection
    except Exception as e:
        print(f"Database connection error: {str(e)}")
        raise e

def update_contract_analysis(connection, analysis_data, contract_id, analysis_id):
    """contract_analyses 테이블의 분석 결과를 업데이트합니다."""
    cursor = connection.cursor()
    
    current_time = datetime.utcnow()
    
    # data 구조에서 필요한 정보 추출
    data = analysis_data.get('data', {})
    summary = data.get('summary', '')
    
    ddobak_commentary = data.get('ddobakCommentary', {})
    overall_comment = ddobak_commentary.get('overallComment', '')
    warning_comment = ddobak_commentary.get('warningComment', '')
    advice = ddobak_commentary.get('advice', '')
    
    # 처리 상태 결정 - Spring Boot enum 값에 맞게 대문자 사용
    success = analysis_data.get('success', False)
    if success:
        process_status = 'COMPLETED'
        status = 'success'
    else:
        process_status = 'FAILED'
        status = 'error'
    
    try:
        # 기존 레코드를 UPDATE (INSERT 대신)
        update_query = """
            UPDATE contract_analyses 
            SET summary = %s, 
                status = %s, 
                ddobak_overall_comment = %s, 
                ddobak_warning_comment = %s, 
                ddobak_advice = %s, 
                process_status = %s, 
                updated_at = %s
            WHERE id = %s
        """
        
        cursor.execute(update_query, (
            summary, status, overall_comment, warning_comment, 
            advice, process_status, current_time, analysis_id
        ))
        
        # 업데이트된 행이 있는지 확인
        if cursor.rowcount == 0:
            print(f"Warning: No rows updated for analysis_id: {analysis_id}")
        else:
            print(f"Updated contract analysis with ID: {analysis_id}")
        
        return analysis_id
        
    except Exception as e:
        print(f"Error updating contract analysis: {str(e)}")
        raise e
    finally:
        cursor.close()

def insert_toxic_clauses(connection, analysis_id, toxic_clauses):
    """toxic_clauses 테이블에 독소조항들을 삽입합니다."""
    cursor = connection.cursor()
    
    try:
        # 먼저 기존 독소조항들을 삭제
        delete_query = "DELETE FROM toxic_clauses WHERE analysis_id = %s"
        cursor.execute(delete_query, (analysis_id,))
        
        if not toxic_clauses:
            print("No toxic clauses to insert")
            return
        
        # 새로운 독소조항들을 삽입
        insert_query = """
            INSERT INTO toxic_clauses 
            (id, analysis_id, clause, reason, reason_reference, 
             source_contract_tag_idx, warn_level)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        for toxic in toxic_clauses:
            toxic_id = str(uuid.uuid4())
            clause = toxic.get('clause', '')
            reason = toxic.get('reason', '')
            reason_reference = toxic.get('reasonReference', '')
            source_idx = toxic.get('sourceContractTagIdx', 0)
            warn_level = toxic.get('warnLevel', 1)
            
            cursor.execute(insert_query, (
                toxic_id, analysis_id, clause, reason, reason_reference,
                source_idx, warn_level
            ))
            
            print(f"Inserted toxic clause with ID: {toxic_id}")
        
    except Exception as e:
        print(f"Error inserting toxic clauses: {str(e)}")
        raise e
    finally:
        cursor.close()

def process_sqs_message(message_body):
    """SQS 메시지를 처리합니다."""
    try:
        # SQS 메시지는 Lambda destination에서 온 것이므로 특정 구조를 가집니다
        if isinstance(message_body, str):
            message_data = json.loads(message_body)
        else:
            message_data = message_body
            
        # Lambda destination에서 오는 메시지 구조 처리
        if 'responsePayload' in message_data:
            bedrock_response = message_data['responsePayload']
        else:
            bedrock_response = message_data
            
        # bedrock_lambda의 새로운 응답 구조에서 데이터 추출
        if 'data' in bedrock_response and 'contractId' in bedrock_response['data']:
            # 새로운 형식: { "data": { "contractId": "...", "analysisId": "...", "analysisResult": {...} } }
            contract_id = bedrock_response['data']['contractId']
            analysis_id = bedrock_response['data']['analysisId']
            
            # analysisResult 구조 확인
            analysis_result_data = bedrock_response['data']['analysisResult']
            
            # analysisResult 안에 다시 analysisResult가 중첩된 경우 처리
            if isinstance(analysis_result_data, dict) and 'analysisResult' in analysis_result_data:
                # 중첩된 구조: analysisResult.analysisResult에 실제 데이터가 있는 경우
                actual_analysis_result = analysis_result_data['analysisResult']
                # bedrock_response 전체 구조를 유지하되, 실제 분석 결과로 교체
                analysis_result = {
                    'success': bedrock_response.get('success', True),
                    'message': bedrock_response.get('message', ''),
                    'data': actual_analysis_result
                }
            else:
                # 정상적인 구조인 경우
                analysis_result = bedrock_response
        else:
            # 이전 형식 또는 다른 형식 처리 (호환성 유지)
            contract_id = message_data.get('requestPayload', {}).get('contractId', 'unknown')
            analysis_id = message_data.get('requestPayload', {}).get('analysisId', 'unknown')
            analysis_result = bedrock_response
        
        return analysis_result, contract_id, analysis_id
        
    except Exception as e:
        print(f"Error processing SQS message: {str(e)}")
        raise e

def lambda_handler(event, context):
    """SQS 트리거로 실행되는 메인 핸들러"""
    print(f"Received event: {json.dumps(event, ensure_ascii=False, indent=2)}")
    
    connection = None
    processed_messages = 0
    failed_messages = 0
    
    try:
        # PostgreSQL 연결
        connection = get_db_connection()
        
        # SQS 레코드들 처리
        for record in event.get('Records', []):
            try:
                message_body = record['body']
                print(f"Processing message: {message_body}")
                
                # SQS 메시지에서 분석 결과 추출
                analysis_result, contract_id, analysis_id = process_sqs_message(message_body)
                
                # 트랜잭션 시작
                connection.autocommit = False
                
                # contract_analyses 테이블 업데이트
                analysis_id = update_contract_analysis(connection, analysis_result, contract_id, analysis_id)
                
                # toxic_clauses 테이블에 삽입
                toxic_clauses = analysis_result.get('data', {}).get('toxics', [])
                insert_toxic_clauses(connection, analysis_id, toxic_clauses)
                
                # 트랜잭션 커밋
                connection.commit()
                processed_messages += 1
                
                print(f"Successfully processed message for contract_id: {contract_id}")
                
            except Exception as e:
                # 트랜잭션 롤백
                if connection:
                    connection.rollback()
                failed_messages += 1
                print(f"Failed to process message: {str(e)}")
                # 개별 메시지 실패는 전체 처리를 중단하지 않음
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Processing completed. Success: {processed_messages}, Failed: {failed_messages}',
                'processed': processed_messages,
                'failed': failed_messages
            })
        }
        
    except Exception as e:
        print(f"Lambda handler error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to process SQS messages'
            })
        }
        
    finally:
        if connection:
            connection.close()
