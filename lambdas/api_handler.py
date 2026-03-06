import json
import uuid
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client(
    "sqs",
    region_name="us-east-1"
)

TABLE_NAME = os.environ["TABLE_NAME"]
QUEUE_URL = os.environ["QUEUE_URL"]

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):

    method = None
    path = None

    if "requestContext" in event:
        rc = event["requestContext"]
        if "http" in rc:
            method = rc["http"]["method"]
            path = event.get("rawPath", "")
        else:
            method = event.get("httpMethod")
            path = event.get("path")
    else:
        method = event.get("httpMethod")
        path = event.get("path")

    # POST /events/{preset}
    if method == "POST":
        preset = event.get("pathParameters", {}).get("preset")
        if not preset:
            return response(400, {"error": "Missing preset"})

        event_id = str(uuid.uuid4())

        item = {
            "eventId": event_id,
            "preset": preset,
            "eventType": preset.split("-")[0].upper(),
            "priority": get_priority(preset),
            "state": "CREATED",
            "createdAt": datetime.utcnow().isoformat()
        }

        print("Before DynamoDB")

        table.put_item(Item=item)

        print("After DynamoDB")

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(item)
        )

        print("After SQS")
       
        return response(201, {"eventId": event_id})

    # GET /events
    if method == "GET" and path and path.endswith("/events"):
        result = table.scan()
        items = result.get("Items", [])
        items.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
        return response(200, items)

    # GET /analytics
    if method == "GET" and path and path.endswith("/analytics"):
        return analytics()

    return response(404, {"error": "Not found"})


def analytics():
    items = table.scan().get("Items", [])

    data = {
        "totalEvents": len(items),
        "byPriority": {},
        "byType": {}
    }

    for item in items:
        p = item.get("priority")
        t = item.get("eventType")
        data["byPriority"][p] = data["byPriority"].get(p, 0) + 1
        data["byType"][t] = data["byType"].get(t, 0) + 1

    return response(200, data)


def get_priority(preset):
    if "security" in preset:
        return "P1"
    if "system" in preset:
        return "P2"
    if "manual" in preset:
        return "P3"
    return "P4"


def response(code, body):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "*"
        },
        "body": json.dumps(body)
    }