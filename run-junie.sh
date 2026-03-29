#!/bin/bash
LOG_FILE="/tmp/junie-proxy.log"

echo "=== Starting Junie proxy setup at $(date) ===" | tee -a "$LOG_FILE"

# Kill any existing GOST processes
echo "Checking for existing GOST processes..." | tee -a "$LOG_FILE"
pkill -f "gost -L" 2>/dev/null || true
sleep 1

# Find the Java truststore
JAVA_TRUSTSTORE=$(find /usr/local/share/junie -name "cacerts" -path "*/lib/security/*" | head -1)
echo "Found Java truststore at: $JAVA_TRUSTSTORE" | tee -a "$LOG_FILE"

# Import the sandbox proxy CA into Java truststore (as root)
if [ -f /usr/local/share/ca-certificates/proxy-ca.crt ]; then
    echo "Importing proxy CA certificate into Java truststore (as root)..." | tee -a "$LOG_FILE"
    # Delete existing alias first (ignore error if it doesn't exist)
    sudo keytool -delete -alias docker-sandbox-proxy -keystore "$JAVA_TRUSTSTORE" -storepass changeit 2>/dev/null || true
    # Import the certificate
    sudo keytool -import -noprompt -trustcacerts -alias docker-sandbox-proxy \
        -file /usr/local/share/ca-certificates/proxy-ca.crt \
        -keystore "$JAVA_TRUSTSTORE" \
        -storepass changeit 2>> "$LOG_FILE"
    echo "Certificate import completed" | tee -a "$LOG_FILE"
else
    echo "Warning: Proxy CA certificate not found at /usr/local/share/ca-certificates/proxy-ca.crt" | tee -a "$LOG_FILE"
fi

# Start GOST as a forward proxy, using the sandbox's built-in proxy for outbound
echo "Starting GOST forward proxy..." | tee -a "$LOG_FILE"
gost -L http://:55432 -F http://host.docker.internal:3128 &>> /tmp/gost.log &
GOST_PID=$!
echo "GOST started with PID: $GOST_PID" | tee -a "$LOG_FILE"

# Wait for GOST to start
sleep 2

# Check if GOST is running
if ! kill -0 $GOST_PID 2>/dev/null; then
    echo "GOST failed to start!" | tee -a "$LOG_FILE"
    cat /tmp/gost.log >> "$LOG_FILE"
    exit 1
fi

echo "GOST is running. Testing connectivity..." | tee -a "$LOG_FILE"

# Test the proxy
curl -x http://127.0.0.1:55432 https://junie.jetbrains.com -I &>> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "Creating proxychains config..." | tee -a "$LOG_FILE"

# Create proxychains config for local GOST
cat > /tmp/proxychains.conf << EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
http 127.0.0.1 55432
EOF

echo "=== Running Junie with proxychains at $(date) ===" >> "$LOG_FILE"
cat /tmp/proxychains.conf >> "$LOG_FILE"

# Set Java SSL options to use our truststore and disable verification
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=$JAVA_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=changeit"

# Run Junie with proxychains forcing all traffic through local GOST
exec proxychains4 -f /tmp/proxychains.conf junie "$@" 2>> "$LOG_FILE"
