import boto3
import os
import json
from datetime import datetime

sns = boto3.client("sns")
cloudwatch = boto3.client("cloudwatch")

TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="Critical Event",
        Message=json.dumps(event)
    )

    cloudwatch.put_metric_data(
        Namespace="EventSystem",
        MetricData=[
            {
                "MetricName": "CriticalEvents",
                "Timestamp": datetime.utcnow(),
                "Value": 1,
                "Unit": "Count"
            }
        ]
    )

    return event