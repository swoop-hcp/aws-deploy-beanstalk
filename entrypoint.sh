#!/bin/bash
set -e

APP_NAME=$1
ENV_NAME=$2
VERSION=$3
REGION=$4
S3_BUCKET=$5
APPLICATION=$6
WAIT=$7

echo "Deploying to Elastic Beanstalk..."
echo "  Application: $APP_NAME"
echo "  Environment: $ENV_NAME"
echo "  Version:     $VERSION"
echo "  Region:      $REGION"
echo "  S3 Bucket:   $S3_BUCKET"
echo "  Application: $APPLICATION"
echo "  Wait Time:   $WAIT"

aws s3 cp "$APPLICATION" "s3://$S3_BUCKET/$APP_NAME/$VERSION.zip"
aws elasticbeanstalk create-application-version --application-name $APP_NAME --version-label $VERSION --source-bundle S3Bucket="$S3_BUCKET",S3Key="$APP_NAME/$VERSION.zip" 

SUCCESS=true
aws elasticbeanstalk update-environment \
  --application-name "$APP_NAME" \
  --environment-name "$ENV_NAME" \
  --version-label "$VERSION" \
  --region "$REGION"

while true; do
    ENV_INFO=$(aws elasticbeanstalk describe-environments --application-name "$APP_NAME" --environment-names "$ENV_NAME" )
    STATUS=$(echo "$ENV_INFO" | jq -r '.Environments[0].Status')
    HEALTH=$(echo "$ENV_INFO" | jq -r '.Environments[0].Health')
    HEALTH_STATUS=$(echo "$ENV_INFO" | jq -r '.Environments[0].HealthStatus')
    if [[ "$STATUS" == "Ready" && "$HEALTH" == "Green" ]]; then
        SUCCESS=true
    break
    elif [[ "$HEALTH" == "Red" || "$HEALTH_STATUS" == "Degraded" ]]; then
        SUCCESS=false
        echo "Deployment failed!"
        aws elasticbeanstalk describe-events --environment-name "$ENV_NAME" --max-items 5
        exit 1
    fi
    echo "Deployment status: $STATUS. Waiting..."
    sleep "$WAIT"
done
ERRORS=$(aws elasticbeanstalk describe-events --environment-name "$ENV_NAME" --max-items 5 --query "Events[?contains(Message, 'Failed') || contains(Message, 'error') || contains(Message, 'Unsuccessful')].[EventDate, Message]" --output text)
if [[ "$ERRORS" == "None" || -z "$ERRORS" ]]; then
    echo "Deployment completed successfully."
else
    echo $ERRORS
    echo "Deployment failed!"
    exit 1
fi
