#!/bin/bash

# Extract input JSON (Terraform passes arguments as JSON to stdin)
# We don't strictly need the input for this simple lookup if we hardcode the tag,
# but parsing it allows for more flexibility if we wanted to pass the tag key/value.
# For now, we'll just read it to be a good citizen, even if we assume the tag.
# eval "$(jq -r '@sh "TAG_KEY=\(.tag_key) TAG_VALUE=\(.tag_value)"')"

# Hardcoded for safety/simplicity in this specific fix, matching the plan
TAG_KEY="ingress.k8s.aws/stack"
TAG_VALUE="unbox-prod"

# Query AWS ALB by Tag
# We use `aws resourcegroupstaggingapi` or `aws elbv2 describe-load-balancers`
# describe-load-balancers doesn't support filtering by tags directly in a simple way 
# without fetching all and filtering client-side (or using JMESPath).
# But resourcegroupstaggingapi is good for tags.
# However, `aws elbv2 describe-load-balancers` is more standard for ALB details.
# Let's use `aws elbv2` and filter.

# Fetch ARNs of ALBs that *might* match (can't filter by tag in describe-load-balancers directly easily)
# Actually, the most robust way is to finding the ALB that has the specific tag.

# "aws elbv2 describe-load-balancers" returns all.
# We can loop or use a more complex JMESPath. 
# Or we can use `aws resourcegroupstaggingapi get-resources --tag-filters Key=...,Values=... --resource-type-filters elasticloadbalancing:loadbalancer`

ARN=$(aws resourcegroupstaggingapi get-resources \
  --resource-type-filters elasticloadbalancing:loadbalancer \
  --tag-filters Key="${TAG_KEY}",Values="${TAG_VALUE}" \
  --query 'ResourceTagMappingList[0].ResourceARN' \
  --output text)

if [ "$ARN" == "None" ] || [ -z "$ARN" ]; then
  # Not found - return empty JSON (not error)
  # Terraform `external` data source expects a valid JSON object.
  # We return an object with empty strings.
  echo '{"arn": "", "dns_name": "", "zone_id": ""}'
  exit 0
fi

# If found, get the DNS name and Zone ID
DETAILS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ARN" \
  --query 'LoadBalancers[0].{DNSName:DNSName, CanonicalHostedZoneId:CanonicalHostedZoneId}' \
  --output json)

DNS_NAME=$(echo "$DETAILS" | jq -r '.DNSName')
ZONE_ID=$(echo "$DETAILS" | jq -r '.CanonicalHostedZoneId')

# Return JSON
jq -n \
  --arg arn "$ARN" \
  --arg dns "$DNS_NAME" \
  --arg zone "$ZONE_ID" \
  '{"arn": $arn, "dns_name": $dns, "zone_id": $zone}'
