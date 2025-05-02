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

EXISTS=$(aws elasticbeanstalk describe-application-versions \
    --application-name $APP_NAME \
    --version-labels $VERSION \
    --query "ApplicationVersions[0].VersionLabel" \
    --region "$REGION" \
    --output text)
if [ "$EXISTS" == "None" ]; then
    # S3_KEY="$APP_NAME/$VERSION.zip"
    # S3_APP_URL="s3://$S3_BUCKET/$APP_NAME/$VERSION.zip"
    # echo "S3 Bucket: $S3_BUCKET, S3 Key: $S3_KEY"
    # echo "S3 App URL: $S3_APP_URL"
    # aws s3 cp "$APPLICATION" $S3_APP_URL    

    # aws elasticbeanstalk create-application-version --application-name $APP_NAME --version-label $VERSION --source-bundle S3Bucket="$S3_BUCKET",S3Key="$S3_KEY"




    S3_KEY="$APP_NAME/$VERSION.zip"
    S3_FILE="s3://$S3_BUCKET/$S3_KEY"

    echo "Uploading to s3 bucket"
    aws s3 cp $APPLICATION $S3_FILE
    echo "Uploaded file $S3_FILE"
    aws elasticbeanstalk create-application-version --application-name $APP_NAME --version-label $VERSION --source-bundle S3Bucket="$S3_BUCKET",S3Key="$S3_KEY" 
    echo "Created app version $VERSION with S3Bucket=$S3_BUCKET,S3Key=$S3_KEY"


else
    echo "Aplication Version Label [$VERSION] already exists, using this one."
fi

echo  "Uploaded file"

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
