#!/bin/bash

if [ $# -ne 1 ] ; then
  echo "Usage: ./dynamodb-put-item.sh <item-string>" ; exit 1
fi

ITEM=$1

# Test putting item to session dynamodb-table, ...
aws dynamodb put-item --profile GEHC-077 --table gabelbombe-sandbox-session --item "{\"token\": {\"S\": \"$ITEM\"}}"

# ... then query it.
aws dynamodb scan --profile GEHC-077 --table gabelbombe-sandbox-session
