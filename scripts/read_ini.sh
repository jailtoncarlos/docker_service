#!/bin/bash

# For .ini parsing: You can use built-in bash commands (grep, sed, awk) without additional dependencies.
# ini file:
# [database]
# user=postgres
# password=secret
# host=localhost

# Function to read a value from an ini file
function read_ini() {
    local file=$1
    local section=$2
    local key=$3

    # Extract the value using grep and sed
    value=$(sed -nr "/^\[$section\]/ { :l /^$key[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" $file)
    echo $value
}

# Example usage
user=$(read_ini "config.ini" "database" "user")
echo "User: $user"
