#!/bin/sh
# Writes the htpasswd files that the HTTP_BASIC and HTTP_BASIC1 directives read.

set -e

generate_htpasswd() {
    local username="$1"
    local password="$2"
    local output_file="$3"
    
    if [ -n "$username" ] && [ -n "$password" ] && [ "$username" != "none" ]; then
        echo "Generating $output_file for user: $username"
        # APR1 is a hash format nginx auth_basic reads.
        hash=$(echo "$password" | openssl passwd -apr1 -stdin)
        echo "${username}:${hash}" > "$output_file"
        chmod 644 "$output_file"
    else
        echo "Skipping $output_file (no credentials provided)"
    fi
}

# HTTP_BASIC: / and the demi locations, dev/test only.
generate_htpasswd "${USERNAME}" "${PASSWORD}" "/tmp/.htpasswd"

# HTTP_BASIC1: /eguide, prod only.
generate_htpasswd "${USERNAME1}" "${PASSWORD1}" "/tmp/.htpasswd1"

echo "HTTP Basic Auth setup complete"
exit 0
