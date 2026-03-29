#!/bin/bash

# Find the Java truststore
JAVA_TRUSTSTORE=$(find /usr/local/share/junie -name "cacerts" -path "*/lib/security/*" | head -1)

# Import the sandbox proxy CA into Java truststore
if [ -f /usr/local/share/ca-certificates/proxy-ca.crt ] && [ -n "$JAVA_TRUSTSTORE" ]; then
    # Delete existing alias first (ignore error if it doesn't exist)
    sudo keytool -delete -alias docker-sandbox-proxy -keystore "$JAVA_TRUSTSTORE" -storepass changeit 2>/dev/null || true
    # Import the certificate
    sudo keytool -import -noprompt -trustcacerts -alias docker-sandbox-proxy \
        -file /usr/local/share/ca-certificates/proxy-ca.crt \
        -keystore "$JAVA_TRUSTSTORE" \
        -storepass changeit 2>/dev/null
fi
