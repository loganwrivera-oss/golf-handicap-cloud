import json
import boto3
import time
from datetime import datetime

# Initialize the Database Connection
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('golf-handicap-scores')

def calculate_differential(score, course_rating, slope_rating):
    if slope_rating == 0:
        return 0.0
    diff = (score - course_rating) * (113 / slope_rating)
    return round(diff, 1)

def lambda_handler(event, context):
    print("Received event:", event)
    
    try:
        # 1. Parse Input
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event
            
        scores_list = body.get('scores', [])
        
        # 2. Calculate Logic
        differentials = []
        for round_data in scores_list:
            s = float(round_data['score'])
            r = float(round_data['rating'])
            sl = float(round_data['slope'])
            diff = calculate_differential(s, r, sl)
            differentials.append(diff)
            
        if not differentials:
            handicap_index = 0.0
        else:
            sorted_diffs = sorted(differentials)
            num_to_count = min(len(sorted_diffs), 8)
            subset = sorted_diffs[:num_to_count]
            average = sum(subset) / len(subset)
            handicap_index = int(average * 10) / 10.0
        
        # 3. SAVE TO DYNAMODB (New!)
        # We will create a timestamp so we know when the user checked
        timestamp = str(datetime.now())
        
        table.put_item(Item={
            'UserId': 'demo_user',        # In a real app, this would be their login email
            'DatePlayed': timestamp,      # Using timestamp as unique ID for this calculation
            'HandicapResult': str(handicap_index),
            'RoundsCalculated': len(differentials)
        })
        
        print(f"Saved handicap {handicap_index} to DynamoDB")

        # 4. Return Result
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'handicap_index': handicap_index,
                'message': 'Score saved to database!'
            })
        }
        
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }