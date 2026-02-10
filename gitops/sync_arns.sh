#!/bin/bash

# Script to sync Target Group ARNs from Terraform output to Helm values.yaml
# Usage: ./sync_arns.sh

# Path to Terraform directory
TF_DIR="../terraform/environments/dev"
# Path to GitOps directory (relative to script location, assuming script is in gitops/)
GITOPS_DIR="."

echo "Fetching Target Group ARNs from Terraform..."

# Check if terraform command exists
if ! command -v terraform &> /dev/null; then
    echo "Error: terraform command not found."
    exit 1
fi

# Get JSON output from Terraform
ARNS_JSON=$(terraform -chdir="$TF_DIR" output -json target_group_arns)

if [ -z "$ARNS_JSON" ]; then
    echo "Error: Failed to get terraform output."
    exit 1
fi

# Function to update values.yaml
update_arn() {
    local service=$1
    local arn=$2
    local file="$GITOPS_DIR/apps/$service/values.yaml"

    if [ -f "$file" ]; then
        echo "Updating $service ARN to $arn in $file..."
        # Use sed to replace the line containing targetGroupArn
        # Assuming the format is: targetGroupArn: "..."
        # We use a temporary file for cross-platform sed compatibility
        sed -i.bak "s|targetGroupArn: \".*\"|targetGroupArn: \"$arn\"|g" "$file" && rm "$file.bak"
    else
        echo "Warning: Values file for $service not found at $file"
    fi
}

# Parse JSON and update files (requires jq)
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. Please install jq."
    exit 1
fi

echo "Parsing ARNs..."
USER_ARN=$(echo "$ARNS_JSON" | jq -r '.user')
PRODUCT_ARN=$(echo "$ARNS_JSON" | jq -r '.product')
ORDER_ARN=$(echo "$ARNS_JSON" | jq -r '.order')
TRADE_ARN=$(echo "$ARNS_JSON" | jq -r '.trade')
PAYMENT_ARN=$(echo "$ARNS_JSON" | jq -r '.payment')

update_arn "user" "$USER_ARN"
update_arn "product" "$PRODUCT_ARN"
update_arn "order" "$ORDER_ARN"
update_arn "trade" "$TRADE_ARN"
update_arn "payment" "$PAYMENT_ARN"

echo "Done!"
