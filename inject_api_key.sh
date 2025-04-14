#!/bin/bash

# Load .env variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Replace placeholder with actual key
sed "s/{{API_KEY}}/${GOOGLE_MAPS_API_KEY}/" web/index.template.html > web/index.html

echo "Injected API key into web/index.html"