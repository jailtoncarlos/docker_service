#!/bin/bash
# For .json parsing: It is recommended to use jq (install with sudo apt-get install jq on Ubuntu).
 # json file:
 # {
 #  "database": {
 #    "user": "postgres",
 #    "password": "secret",
 #    "host": "localhost"
 #  }
 #}

# Read a JSON key using jq
user=$(jq -r '.database.user' config.json)
echo "User: $user"
