#!/bin/bash
set -e

APP_NAME=$1
ENV_NAME=$2
VERSION=$3
REGION=$4
S3_BUCKET=$5
APPLICATION=$6
WAIT=$7

aws configure set region "$REGION"

echo "Deploying to Elastic Beanstalk..."
echo "  Application: $APP_NAME"
echo "  Environment: $ENV_NAME"
echo "  Version:     $VERSION"
echo "  Region:      $REGION"
echo "  S3 Bucket:   $S3_BUCKET"
echo "  Application: $APPLICATION"
echo "  Wait Time:   $WAIT"

echo "First query to aws"
EXISTS=$(aws elasticbeanstalk describe-application-versions \
    --application-name $APP_NAME \
    --version-labels $VERSION \
    --query "ApplicationVersions[0].VersionLabel" \
    --region "$REGION" \
    --output text)
echo "Got response from first query"
if [ "$EXISTS" == "None" ]; then
    aws s3 cp "$APPLICATION" "s3://$S3_BUCKET/$APP_NAME/$VERSION.zip" --region "$REGION"
    aws elasticbeanstalk create-application-version --application-name $APP_NAME --version-label $VERSION --source-bundle S3Bucket="$S3_BUCKET",S3Key="$APP_NAME/$VERSION.zip"  --region $REGION
else
    echo "Aplication Version Label [$VERSION] already exists, using this one."
fi

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
    LOGS=$(aws elasticbeanstalk describe-events --environment-name "$ENV_NAME"  --max-items 2)
    ERRORS=$(echo "$LOGS" | jq -r '.Events[] | select((.Message | test("Failed to deploy application")) or (.Severity == "Error")) | [.EventDate, .Severity, .Message] | @tsv')
    SUCCESS=$(echo "$LOGS" | jq -r '.Events[] | select((.Message | test("Environment update completed successfully"))) | [.EventDate, .Severity, .Message] | @tsv')
    if [[ -n "$ERRORS" ]]; then
        echo "❌ Deployment failed:"
        echo "$ERRORS"
        exit 1
    fi
    if [[ -n "$SUCCESS" && "$STATUS" == "Ready" && "$HEALTH" == "Green" ]]; then
        echo "✅ Deployment completed successfully."
        echo "$SUCCESS"
        exit 0
    fi
    echo "Deployment status: $STATUS. Waiting..."
    sleep "$WAIT"
done
