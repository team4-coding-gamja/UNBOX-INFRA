import json
import gzip
import base64
import os
import urllib.request
import urllib.parse
from datetime import datetime

DISCORD_WEBHOOK_URL = os.environ['DISCORD_WEBHOOK_URL']

def lambda_handler(event, context):
    # CloudWatch Logs 데이터 디코딩
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_data = json.loads(uncompressed_payload)
    
    log_group = log_data['logGroup']
    log_stream = log_data['logStream']
    
    # 서비스 이름 추출 (예: /ecs/unbox-dev/user -> user)
    service_name = log_group.split('/')[-1] if '/' in log_group else 'unknown'
    
    # 로그 이벤트 처리
    for log_event in log_data['logEvents']:
        message = log_event['message']
        timestamp = datetime.fromtimestamp(log_event['timestamp'] / 1000).strftime('%Y-%m-%d %H:%M:%S')
        
        # ERROR 또는 WARNING 레벨 확인
        log_level = 'ERROR' if 'ERROR' in message.upper() else 'WARNING'
        color = 15158332 if log_level == 'ERROR' else 16776960  # Red for ERROR, Yellow for WARNING
        
        # Discord 임베드 메시지 생성
        embed = {
            "embeds": [{
                "title": f"🚨 {log_level} - {service_name.upper()} 서비스",
                "description": f"```\n{message[:1900]}\n```",  # Discord 제한: 2000자
                "color": color,
                "fields": [
                    {
                        "name": "서비스",
                        "value": service_name,
                        "inline": True
                    },
                    {
                        "name": "로그 레벨",
                        "value": log_level,
                        "inline": True
                    },
                    {
                        "name": "시간",
                        "value": timestamp,
                        "inline": True
                    },
                    {
                        "name": "로그 그룹",
                        "value": log_group,
                        "inline": False
                    },
                    {
                        "name": "로그 스트림",
                        "value": log_stream,
                        "inline": False
                    }
                ],
                "timestamp": datetime.utcnow().isoformat()
            }]
        }
        
        # Discord Webhook 전송
        try:
            req = urllib.request.Request(
                DISCORD_WEBHOOK_URL,
                data=json.dumps(embed).encode('utf-8'),
                headers={'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req) as response:
                print(f"Discord notification sent: {response.status}")
        except Exception as e:
            print(f"Failed to send Discord notification: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notifications sent')
    }
