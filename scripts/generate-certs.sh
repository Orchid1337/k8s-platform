#!/bin/bash
# =============================================================================
# Generate Self-Signed Certificates
# Creates TLS certificates for local development (not for production use).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_DIR/.certs"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

# Create certs directory
mkdir -p "$CERTS_DIR"

# ---------------------------------------------------------------------------
# Generate CA certificate
# ---------------------------------------------------------------------------
log_info "Generating CA certificate..."

openssl genrsa -out "$CERTS_DIR/ca.key" 4096

openssl req -x509 -new -nodes \
    -key "$CERTS_DIR/ca.key" \
    -sha256 -days 365 \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/C=US/ST=Local/L=Dev/O=k8s-platform/CN=k8s-platform-ca"

log_success "CA certificate generated"

# ---------------------------------------------------------------------------
# Generate server certificate for app.local
# ---------------------------------------------------------------------------
log_info "Generating server certificate for app.local..."

openssl genrsa -out "$CERTS_DIR/tls.key" 2048

openssl req -new \
    -key "$CERTS_DIR/tls.key" \
    -out "$CERTS_DIR/tls.csr" \
    -subj "/C=US/ST=Local/L=Dev/O=k8s-platform/CN=app.local"

# Create extension file for SAN
cat > "$CERTS_DIR/ext.cnf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = app.local
DNS.2 = *.app.local
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

openssl x509 -req \
    -in "$CERTS_DIR/tls.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/tls.crt" \
    -days 365 \
    -sha256 \
    -extfile "$CERTS_DIR/ext.cnf"

log_success "Server certificate generated"

# ---------------------------------------------------------------------------
# Create Kubernetes TLS secret
# ---------------------------------------------------------------------------
log_info "Creating Kubernetes TLS secret..."

export KUBECONFIG="$PROJECT_DIR/kubeconfig"

kubectl create secret tls app-tls \
    --cert="$CERTS_DIR/tls.crt" \
    --key="$CERTS_DIR/tls.key" \
    --namespace app \
    --dry-run=client -o yaml | kubectl apply -f -

log_success "TLS secret created in app namespace"

# ---------------------------------------------------------------------------
# Cleanup temporary files
# ---------------------------------------------------------------------------
rm -f "$CERTS_DIR/tls.csr" "$CERTS_DIR/ext.cnf" "$CERTS_DIR/ca.srl"

echo ""
echo -e "${GREEN}Certificates generated successfully!${NC}"
echo ""
echo "  CA Certificate:     $CERTS_DIR/ca.crt"
echo "  Server Certificate: $CERTS_DIR/tls.crt"
echo "  Server Key:         $CERTS_DIR/tls.key"
echo ""
echo "  To trust the CA on macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERTS_DIR/ca.crt"
echo "  To trust the CA on Linux: sudo cp $CERTS_DIR/ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates"
