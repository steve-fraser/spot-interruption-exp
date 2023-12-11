#!/usr/bin/env bash
ROLE_NAME=my-fis-role
INSTANCE=arn:aws:ec2:us-west-2:854602782980:instance/i-02a7f95e9fd2c8ba6
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://fis_role_trust_policy.json


aws iam put-role-policy --role-name $ROLE_NAME --policy-name $ROLE_NAME --policy-document file://fis_role_permissions_policy.json

export FIS_ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME | jq -r '.Role.Arn')
echo Found ARN: $FIS_ROLE_ARN


cat <<EoF > spot_experiment.json
{
    "description": "Test Spot Instance interruptions",
    "targets": {
        "SpotInstancesInASG": {
            "resourceType": "aws:ec2:spot-instance",
            "resourceArns": [
                "$INSTANCE"
            ],
            "selectionMode": "ALL"
        }
    },
    "actions": {
        "interruptSpotInstance": {
            "actionId": "aws:ec2:send-spot-instance-interruptions",
            "parameters": {
                "durationBeforeInterruption": "PT2M"
            },
            "targets": {
                "SpotInstances": "SpotInstancesInASG"
            }
        }
    },
    "stopConditions": [
        {
            "source": "none"
        }
    ],
    "roleArn": "${FIS_ROLE_ARN}",
    "tags": {}
}
EoF

export FIS_TEMPLATE_ID=$(aws fis create-experiment-template --cli-input-json file://spot_experiment.json | jq -r '.experimentTemplate.id')
echo Starting experiment: $FIS_TEMPLATE_ID
aws fis start-experiment --experiment-template-id $FIS_TEMPLATE_ID