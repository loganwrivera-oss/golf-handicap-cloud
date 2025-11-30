import json

def calculate_differential(score, course_rating, slope_rating):
    """Calculates the handicap differential for a single round."""
    if slope_rating == 0:
        return 0.0
    diff = (score - course_rating) * (113 / slope_rating)
    return round(diff, 1)

def lambda_handler(event, context):
    print("Received event:", event) # Logs to CloudWatch (for debugging)
    
    # 1. Parse the Input (The user's list of scores)
    # The API Gateway will send us a "body" containing the data
    try:
        # Check if 'body' exists (it comes from API Gateway) or if we are testing directly
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event
            
        scores_list = body.get('scores', []) # Expecting a list of objects
        
        # 2. Process the Data
        differentials = []
        for round_data in scores_list:
            s = float(round_data['score'])
            r = float(round_data['rating'])
            sl = float(round_data['slope'])
            
            diff = calculate_differential(s, r, sl)
            differentials.append(diff)
            
        # 3. Calculate Index (Average of lowest 8)
        if not differentials:
            handicap_index = 0.0
        else:
            sorted_diffs = sorted(differentials)
            # Use minimal logic: take lowest 8 (or all if < 8)
            num_to_count = min(len(sorted_diffs), 8)
            subset = sorted_diffs[:num_to_count]
            
            # If less than 20 scores, the logic is complex (adjustment table).
            # For this MVP, we simplify: just average the best available.
            average = sum(subset) / len(subset)
            handicap_index = int(average * 10) / 10.0
        
        # 4. Return the Result (JSON format)
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*' # Required for CORS (Frontend access)
            },
            'body': json.dumps({
                'handicap_index': handicap_index,
                'differentials_used': len(differentials)
            })
        }
        
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }