#!/usr/bin/env bash
# Load the Olist CSVs into BigQuery and run the SQL pipeline there.
# Works on the free BigQuery sandbox (no billing account): the pipeline only
# uses CREATE TABLE AS SELECT, which the sandbox allows.
#
# Requirements: Google Cloud SDK (bq CLI) authenticated with `gcloud auth login`.
# Usage: PROJECT_ID=my-project bash scripts/run_bigquery.sh
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID to your GCP project id}"
LOCATION="${LOCATION:-US}"
RAW_DIR="$(dirname "$0")/../data/raw"
SQL_DIR="$(dirname "$0")/../sql"

for dataset in olist_raw olist_mart; do
  bq --location="$LOCATION" mk --dataset --force "$PROJECT_ID:$dataset"
done

load() {
  bq --location="$LOCATION" load --replace --autodetect --skip_leading_rows=1 \
    --source_format=CSV "$PROJECT_ID:olist_raw.$1" "$RAW_DIR/$2"
}
load orders         olist_orders_dataset.csv
load order_payments olist_order_payments_dataset.csv
load customers      olist_customers_dataset.csv

for file in "$SQL_DIR"/0*.sql; do
  echo "running $(basename "$file")"
  bq --location="$LOCATION" query --project_id="$PROJECT_ID" \
    --use_legacy_sql=false --quiet < "$file"
done

echo "quality checks (every failures value must be 0):"
bq --location="$LOCATION" query --project_id="$PROJECT_ID" \
  --use_legacy_sql=false --format=pretty < "$SQL_DIR/99_quality_checks.sql"
