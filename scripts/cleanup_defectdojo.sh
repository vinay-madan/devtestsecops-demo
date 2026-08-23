#!/bin/bash

# --- CONFIGURATION ---
DEFECTDOJO_URL="http://localhost:8080"
API_TOKEN="YOUR_API_TOKEN_HERE"

# The name of the project you want to purge completely
PRODUCT_NAME="Demo App Project"
# ---------------------

if [ "$API_TOKEN" == "YOUR_API_TOKEN_HERE" ]; then
    echo "❌ Error: Please update the API_TOKEN variable with your DefectDojo token."
    exit 1
fi

echo "🔍 Searching for Product: '$PRODUCT_NAME'..."

# Fetch the product details to find its system ID
SEARCH_RESPONSE=$(curl -s -X 'GET' "$DEFECTDOJO_URL/api/v2/products/?name=$PRODUCT_NAME" \
  -H "Authorization: Token $API_TOKEN" \
  -H 'Content-Type: application/json')

# Extract the product ID from the response using sed
PRODUCT_ID=$(echo "$SEARCH_RESPONSE" | sed -E 's/.*"id":([0-9]+).*/\1/')

# Fallback extraction check if response structure varies
if [[ ! "$PRODUCT_ID" =~ ^[0-9]+$ ]]; then
    PRODUCT_ID=$(echo "$SEARCH_RESPONSE" | sed -E 's/.*"results":\[\{"id":([0-9]+).*/\1/')
fi

if [[ ! "$PRODUCT_ID" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Target product '$PRODUCT_NAME' not found or already deleted."
    exit 0
fi

echo "⚠️ Found Product ID: $PRODUCT_ID. Preparing full purge..."
echo "💥 Deleting Product, engagements, and all reports..."

# Send a DELETE request to wipe out the product and all nested dependencies
DELETE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X 'DELETE' "$DEFECTDOJO_URL/api/v2/products/$PRODUCT_ID/" \
  -H "Authorization: Token $API_TOKEN")

if [ "$DELETE_STATUS" -eq 204 ] || [ "$DELETE_STATUS" -eq 200 ]; then
    echo "✅ Successfully purged '$PRODUCT_NAME' and all associated reports from DefectDojo!"
else
    echo "❌ Failed to delete product. (HTTP Status Code: $DELETE_STATUS)"
fi
