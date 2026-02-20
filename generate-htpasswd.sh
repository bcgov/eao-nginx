#!/bin/sh
# Generate htpasswd files from environment variables for HTTP Basic Auth
# Used for dev/test environments to protect eagle-public routes

set -e

# Function to generate htpasswd file
generate_htpasswd() {
    local username="$1"
    local password="$2"
    local output_file="$3"
    
    if [ -n "$username" ] && [ -n "$password" ] && [ "$username" != "none" ]; then
        echo "Generating $output_file for user: $username"
        # Use openssl to generate APR1 hash (compatible with nginx)
        # Echo password to openssl to avoid prompts
        hash=$(echo "$password" | openssl passwd -apr1 -stdin)
        echo "${username}:${hash}" > "$output_file"
        chmod 644 "$output_file"
    else
        echo "Skipping $output_file (no credentials provided)"
    fi
}

# Generate htpasswd files for each auth endpoint
# Main endpoint (/, /admin/, /api) - used in dev/test
generate_htpasswd "${USERNAME}" "${PASSWORD}" "/tmp/.htpasswd"

# E-guide endpoint (/eguide) - used in prod only
generate_htpasswd "${USERNAME1}" "${PASSWORD1}" "/tmp/.htpasswd1"

# Public endpoint (legacy /public path) - used in dev/test
generate_htpasswd "${USERNAME2}" "${PASSWORD2}" "/tmp/.htpasswd2"

echo "HTTP Basic Auth setup complete"
exit 0
