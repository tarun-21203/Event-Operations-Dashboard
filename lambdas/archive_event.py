import boto3
import os
import json

s3 = boto3.client("s3")
BUCKET = os.environ["ARCHIVE_BUCKET"]


def lambda_handler(event, context):

    s3.put_object(
        Bucket=BUCKET,
        Key=f"archive/{event['eventId']}.json",
        Body=json.dumps(event),
        ContentType="application/json"
    )

    return event