#!/bin/bash
# Script to copy RDS snapshot from us-east-2 to us-east-1

set -e

# Configuration
SOURCE_REGION="us-east-2"
TARGET_REGION="us-east-1"
PROFILE="arrow-admin"
SOURCE_SNAPSHOT_ID="exp-manual-migration"  # e.g., "conbench-snapshot-2024-01-15"
TARGET_SNAPSHOT_ID="exp-manual-migration"  # Name in new region

# Get the source snapshot ARN
SOURCE_SNAPSHOT_ARN=$(aws rds describe-db-snapshots \
  --region ${SOURCE_REGION} \
  --db-snapshot-identifier ${SOURCE_SNAPSHOT_ID} \
  --query 'DBSnapshots[0].DBSnapshotArn' \
  --profile "${PROFILE}" \
  --output text)

echo "Source snapshot ARN: ${SOURCE_SNAPSHOT_ARN}"

# Copy snapshot to target region
echo "Copying snapshot to ${TARGET_REGION}..."
aws rds copy-db-snapshot \
  --region ${TARGET_REGION} \
  --source-db-snapshot-identifier ${SOURCE_SNAPSHOT_ARN} \
  --target-db-snapshot-identifier ${TARGET_SNAPSHOT_ID} \
  --profile "${PROFILE}" \
  --copy-tags \
  --kms-key-id alias/aws/rds  # Use default RDS KMS key in target region

echo "Copy initiated. Monitor progress with:"
echo "aws rds describe-db-snapshots --region ${TARGET_REGION} --profile ${PROFILE} --db-snapshot-identifier ${TARGET_SNAPSHOT_ID}"
