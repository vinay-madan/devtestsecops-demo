#!/bin/bash

# --- CONFIGURATION ---
DEFECTDOJO_URL="http://localhost:8080"
API_TOKEN=""

# Names for your new entities
PRODUCT_NAME="Testing Minds Demo"
ENGAGEMENT_NAME="Automated Scan Engagement"

# Path to the directory containing your reports
TARGET_DIR="./out"
# ---------------------

if [ "$API_TOKEN" == "YOUR_API_TOKEN_HERE" ]; then
    echo "❌ Error: Please update the API_TOKEN variable with your DefectDojo token."
    exit 1
fi

echo "🚀 Step 1: Creating Product '$PRODUCT_NAME'..."

# Create Product and capture the JSON response
PROD_RESPONSE=$(curl -s -X 'POST' "$DEFECTDOJO_URL/api/v2/products/" \
  -H "Authorization: Token $API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"name\": \"$PRODUCT_NAME\",
    \"description\": \"Automated security testing sandbox pipeline.\",
    \"prod_type\": 1
  }")

# Extract Product ID using sed
PRODUCT_ID=$(echo "$PROD_RESPONSE" | sed -E 's/.*"id":([0-9]+).*/\1/')

if [[ ! "$PRODUCT_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Failed to create product. Response: $PROD_RESPONSE"
    exit 1
fi

echo "✅ Product created successfully! ID: $PRODUCT_ID"
echo "----------------------------------------"


echo "🚀 Step 2: Creating Interactive Engagement..."

# Get current date and target end date (7 days from now)
START_DATE=$(date +%Y-%m-%d)
END_DATE=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d)

# Create Engagement and capture the JSON response
ENG_RESPONSE=$(curl -s -X 'POST' "$DEFECTDOJO_URL/api/v2/engagements/" \
  -H "Authorization: Token $API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"name\": \"$ENGAGEMENT_NAME\",
    \"target_start\": \"$START_DATE\",
    \"target_end\": \"$END_DATE\",
    \"product\": $PRODUCT_ID,
    \"engagement_type\": \"Interactive\",
    \"status\": \"In Progress\"
  }")

# Extract Engagement ID
ENGAGEMENT_ID=$(echo "$ENG_RESPONSE" | sed -E 's/.*"id":([0-9]+).*/\1/')

if [[ ! "$ENGAGEMENT_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Failed to create engagement. Response: $ENG_RESPONSE"
    exit 1
fi

echo "✅ Engagement created successfully! ID: $ENGAGEMENT_ID"
echo "----------------------------------------"


echo "🚀 Step 3: Starting file uploads to Engagement #$ENGAGEMENT_ID..."

# Define your reports list cleanly for compatibility with older Bash versions
FILES=(
    "$TARGET_DIR/trivy.json|Trivy Scan"
    "$TARGET_DIR/semgrep.sarif|SARIF"
    "$TARGET_DIR/trufflehog.json|Trufflehog Scan"
)

for ITEM in "${FILES[@]}"; do
    # Split the path from its parser format tag
    FILE="${ITEM%%|*}"
    SCAN_TYPE="${ITEM##*|}"

    if [ -f "$FILE" ]; then
        echo "📂 Found $FILE. Uploading as '$SCAN_TYPE'..."

        UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X 'POST' "$DEFECTDOJO_URL/api/v2/import-scan/" \
          -H "Authorization: Token $API_TOKEN" \
          -H 'Content-Type: multipart/form-data' \
          -F 'active=true' \
          -F 'verified=true' \
          -F "scan_type=$SCAN_TYPE" \
          -F "engagement=$ENGAGEMENT_ID" \
          -F "file=@$FILE")

        if [ "$UPLOAD_STATUS" -eq 201 ] || [ "$UPLOAD_STATUS" -eq 200 ]; then
            echo "✅ Successfully imported $FILE"
        else
            echo "❌ Failed to import $FILE (HTTP Status: $UPLOAD_STATUS)"
        fi
    else
        echo "⚠️ Warning: File $FILE not found, skipping."
    fi
    echo "----------------------------------------"
done

echo "🎉 Process finished! Check your local dashboard to view your findings."
