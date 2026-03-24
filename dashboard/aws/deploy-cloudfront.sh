#!/bin/bash
# Deploy CloudFront distribution for Gasclaw Dashboard
# This creates the CloudFront distribution that fronts the GPU server

set -e

STACK_NAME="gasclaw-dashboard-cf"
DOMAIN="status.gpu.villamarket.ai"
ORIGIN_DOMAIN="api.minimax.villamarket.ai"  # The GPU server
ORIGIN_PORT="5000"

echo "☁️  Deploying CloudFront distribution for Gasclaw Dashboard..."
echo "   Stack: $STACK_NAME"
echo "   Domain: $DOMAIN"
echo "   Origin: $ORIGIN_DOMAIN:$ORIGIN_PORT"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

# Check if already logged in
if ! aws sts get-caller-identity &> /dev/null; then
    echo "🔑 AWS authentication required..."
    aws configure
fi

# Get or request certificate
echo ""
echo "🔒 Checking for ACM certificate..."
CERT_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text 2>/dev/null || echo "")

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
    echo "⚠️  No certificate found for $DOMAIN"
    echo "   Requesting certificate..."
    CERT_ARN=$(aws acm request-certificate \
        --domain-name "$DOMAIN" \
        --validation-method DNS \
        --query 'CertificateArn' \
        --output text)
    echo "   Certificate requested: $CERT_ARN"
    echo "   ⚠️  You must validate the certificate via DNS before proceeding!"
    echo "   Check validation status with: aws acm describe-certificate --certificate-arn $CERT_ARN"
    exit 1
else
    echo "✅ Found certificate: $CERT_ARN"
fi

# Check certificate validation status
echo "Checking certificate validation status..."
CERT_STATUS=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --query 'Certificate.Status' \
    --output text)

if [ "$CERT_STATUS" != "ISSUED" ]; then
    echo "⚠️  Certificate status: $CERT_STATUS"
    echo "   Please validate the certificate via DNS first."
    exit 1
fi

# Deploy CloudFormation stack
echo ""
echo "📋 Creating CloudFormation stack..."
aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file cloudfront.yaml \
    --parameter-overrides \
        DomainName="$DOMAIN" \
        OriginDomain="$ORIGIN_DOMAIN" \
        OriginPort="$ORIGIN_PORT" \
        CertificateArn="$CERT_ARN" \
    --capabilities CAPABILITY_IAM

# Get outputs
echo ""
echo "📊 Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`DistributionId`].OutputValue' \
    --output text)

echo ""
echo "✨ CloudFront deployment complete!"
echo ""
echo "🌐 Dashboard will be available at:"
echo "   https://$DOMAIN"
echo ""
echo "⚡ To invalidate cache after updates:"
echo "   aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths '/*'"
echo ""
echo "📊 Monitor distribution:"
echo "   aws cloudfront get-distribution --id $DISTRIBUTION_ID"
