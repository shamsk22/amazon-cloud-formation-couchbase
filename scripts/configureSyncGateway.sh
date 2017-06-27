#!/usr/bin/env bash

echo "Running configureSyncGateway.sh"

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
  | jq '.region'  \
  | sed 's/^"\(.*\)"$/\1/' )

instanceID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
  | jq '.instanceId' \
  | sed 's/^"\(.*\)"$/\1/' )

autoscalingGroup=$(aws ec2 describe-instances \
  --region ${region} \
  --instance-ids ${instanceID} \
  | jq '.Reservations[0]|.Instances[0]|.Tags[] | select( .Key == "aws:autoscaling:groupName") | .Value' \
  | sed 's/^"\(.*\)"$/\1/' )

autoscalingGroupInstanceIDs=$(aws autoscaling describe-auto-scaling-groups \
  --region ${region} \
  --query 'AutoScalingGroups[*].Instances[*].InstanceId' \
  --auto-scaling-group-name ${autoscalingGroup} \
  | grep "i-" | sed 's/ //g' | sed 's/"//g' |sed 's/,//g' | sort)

rallyInstanceID=`echo ${autoscalingGroupInstanceIDs} | cut -d " " -f1`

rallyPublicDNS=$(aws ec2 describe-instances \
    --region ${region} \
    --query  'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName' \
    --instance-ids ${rallyInstanceID} \
    --output text)

serverDNS=${rallyPublicDNS}

echo '
{
  "log": ["*"],
  "databases": {
    "db": {
      "server": "http://${serverDNS}:8091",
      "bucket": "default",
      "users": { "GUEST": { "disabled": false, "admin_channels": ["*"] } }
    }
  }
}
' > /home/sync_gateway/sync_gateway.json