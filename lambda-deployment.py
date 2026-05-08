import json
import os
import urllib3

def lambda_handler(event, context):
    """
    Lambda function to send ECS deployment notifications to Slack
    """
    http = urllib3.PoolManager()
    
    webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    environment = os.environ.get('ENVIRONMENT')
    
    if not webhook_url:
        print("No Slack webhook URL configured")
        return
    
    # Parse ECS deployment event
    detail = event.get('detail', {})
    event_name = detail.get('eventName', 'Unknown')
    
    # Build Slack message
    message = {
        "text": f"ECS Deployment Event in {environment}",
        "attachments": [{
            "color": "good" if "SUCCESS" in event_name else "warning",
            "fields": [
                {
                    "title": "Environment",
                    "value": environment,
                    "short": True
                },
                {
                    "title": "Event",
                    "value": event_name,
                    "short": True
                },
                {
                    "title": "Details",
                    "value": json.dumps(detail, indent=2),
                    "short": False
                }
            ]
        }]
    }
    
    try:
        encoded_data = json.dumps(message).encode('utf-8')
        response = http.request(
            'POST',
            webhook_url,
            body=encoded_data,
            headers={'Content-Type': 'application/json'}
        )
        print(f"Slack notification sent: {response.status}")
    except Exception as e:
        print(f"Error sending Slack notification: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notification sent')
    }