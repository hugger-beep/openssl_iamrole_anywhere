#!/bin/bash

# IAM Roles Anywhere - Complete OpenSSL Certificate Setup Script
# Run in AWS CloudShell or Linux environment

### **🚀 QUICK START: How to Run in AWS CloudShell**
# 1. Open AWS CloudShell: https://console.aws.amazon.com/cloudshell/
# 2. Upload this script: Click "Actions" > "Upload file" > Select openssl.sh
# 3. Make executable: chmod +x openssl.sh
# 4. Run script: ./openssl.sh
# 5. Download certificates: Click "Actions" > "Download file" > Select files from iam-roles-anywhere-certs/
#
# 📝 **CloudShell Commands:**
# wget https://your-domain.com/openssl.sh  # If hosted online
# chmod +x openssl.sh
# ./openssl.sh
# ls -la iam-roles-anywhere-certs/  # View generated files

### **ENGINEER NOTE: WHERE TO RUN THIS SCRIPT**
# 🌐 **RECOMMENDED: AWS CloudShell**
#   - Pre-installed OpenSSL and AWS CLI
#   - No Windows path conversion issues
#   - Direct access to AWS services
#   - Secure environment for certificate generation
#   - Easy file upload/download via web interface
#
# 💻 **ALTERNATIVE: Linux/macOS Terminal**
#   - Requires OpenSSL and AWS CLI installation
#   - Native bash environment
#
# ❌ **NOT RECOMMENDED: Windows Git Bash**
#   - Path conversion issues (MSYS_NO_PATHCONV needed)
#   - Potential OpenSSL compatibility issues
#
# 📁 **EXECUTION LOCATION:**
# Run from any directory - script creates 'iam-roles-anywhere-certs' subdirectory
# All certificates will be generated in: ./iam-roles-anywhere-certs/

### **ENGINEER NOTE: Script Purpose**
# This script creates a complete Public Key Infrastructure (PKI) for IAM Roles Anywhere
# using OpenSSL as an External Trust Anchor. It generates:
# 1. Certificate Authority (CA) - The root of trust
# 2. Client Certificate - For user authentication
# 3. Application Certificate - For application authentication
# All certificates are properly signed and include correct X.509 extensions

set -e  # Exit on any error

echo "=== IAM Roles Anywhere OpenSSL Certificate Generator ==="
echo "Creating complete PKI infrastructure for External Trust Anchor"
echo ""

### **ENGINEER NOTE: Certificate Subject Configuration**
# X.509 Distinguished Names follow the format: /C=Country/ST=State/L=Locality/O=Organization/OU=OrganizationalUnit/CN=CommonName
# CN (Common Name) is the most important field - it identifies the certificate holder
# These subjects can be customized for your organization
CA_SUBJECT="/C=CA/ST=Ontario/L=Toronto/O=MyCompany/OU=Security/CN=MyCompany-Root-CA"
CLIENT_SUBJECT="/C=CA/ST=Ontario/L=Toronto/O=MyCompany/OU=Security/CN=ClientUser"
APP_SUBJECT="/C=CA/ST=Ontario/L=Toronto/O=MyCompany/OU=Security/CN=TestApplication"

# Create output directory
mkdir -p iam-roles-anywhere-certs
cd iam-roles-anywhere-certs

echo "Step 1: Creating Certificate Authority (CA)..."

### **ENGINEER NOTE: CA Private Key Generation**
# RSA 4096-bit key provides strong security for a root CA
# This key will sign all client certificates, so it must be kept secure
# 4096 bits is recommended for CAs (vs 2048 for client certificates)
openssl genrsa -out ca.key 4096

### **ENGINEER NOTE: CA Certificate Creation**
# -new -x509: Creates a self-signed certificate (CA signs itself)
# -days 3650: 10-year validity (CAs typically have long lifespans)
# -extensions v3_ca: Applies CA-specific X.509 v3 extensions
# The inline config defines proper CA extensions:
#   - basicConstraints = CA:TRUE: Marks this as a Certificate Authority
#   - keyUsage = keyCertSign, cRLSign: Allows signing certificates and CRLs
#   - subjectKeyIdentifier: Unique identifier for this CA
#   - authorityKeyIdentifier: Links to the signing authority (self for root CA)
openssl req -new -x509 -key ca.key -out ca.pem -days 3650 \
  -subj "$CA_SUBJECT" \
  -extensions v3_ca \
  -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
[req_distinguished_name]
[v3_ca]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
)

echo "✅ CA Certificate created: ca.pem"
echo "✅ CA Private Key created: ca.key"
echo ""

echo "Step 2: Creating Client Certificate..."

### **ENGINEER NOTE: Client Private Key Generation**
# RSA 2048-bit key is sufficient for client certificates
# Smaller than CA key (4096) but still secure for client authentication
openssl genrsa -out client.key 2048

### **ENGINEER NOTE: Certificate Signing Request (CSR)**
# CSR contains the public key and subject information
# This is what gets sent to the CA for signing
# The private key never leaves the client system
openssl req -new -key client.key -out client.csr \
  -subj "$CLIENT_SUBJECT"

### **ENGINEER NOTE: Client Certificate Signing**
# -req -in client.csr: Process the CSR
# -CA ca.pem -CAkey ca.key: Use our CA to sign the certificate
# -CAcreateserial: Create/update the CA's serial number file
# -days 365: 1-year validity (shorter than CA for security)
# Client certificate extensions:
#   - basicConstraints = CA:FALSE: This is NOT a Certificate Authority
#   - keyUsage = digitalSignature, keyEncipherment: Standard client key usage
#   - extendedKeyUsage = clientAuth: Specifically for client authentication
#   - subjectKeyIdentifier: Unique ID for this certificate
#   - authorityKeyIdentifier: Links back to the signing CA
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key \
  -CAcreateserial -out client.pem -days 365 \
  -extensions v3_client \
  -extfile <(cat <<EOF
[v3_client]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF
)

echo "✅ Client Certificate created: client.pem"
echo "✅ Client Private Key created: client.key"
echo ""

echo "Step 3: Creating Test Application Certificate..."
# Generate application private key
openssl genrsa -out app.key 2048

# Create application certificate signing request
openssl req -new -key app.key -out app.csr \
  -subj "$APP_SUBJECT"

# Sign application CSR with CA certificate
openssl x509 -req -in app.csr -CA ca.pem -CAkey ca.key \
  -CAcreateserial -out app.pem -days 365 \
  -extensions v3_client \
  -extfile <(cat <<EOF
[v3_client]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF
)

echo "✅ Application Certificate created: app.pem"
echo "✅ Application Private Key created: app.key"
echo ""

echo "Step 4: Verifying Certificate Chain..."

### **ENGINEER NOTE: Certificate Chain Verification**
# This is CRITICAL - verifies that certificates are properly signed by the CA
# openssl verify -CAfile ca.pem client.pem:
#   - Checks that client.pem was signed by ca.pem
#   - Validates the certificate chain: CA -> Client
#   - Ensures the signature is cryptographically valid
# If verification fails, IAM Roles Anywhere will reject the certificate
openssl verify -CAfile ca.pem client.pem
openssl verify -CAfile ca.pem app.pem

echo ""
echo "Step 5: Certificate Information..."
echo "--- CA Certificate ---"
openssl x509 -noout -subject -issuer -dates -in ca.pem

echo ""
echo "--- Client Certificate ---"
openssl x509 -noout -subject -issuer -dates -in client.pem

echo ""
echo "--- Application Certificate ---"
openssl x509 -noout -subject -issuer -dates -in app.pem

echo ""
echo "Step 6: Creating AWS CLI Commands..."

### **ENGINEER NOTE: AWS Integration Commands**
# These commands integrate your OpenSSL PKI with AWS IAM Roles Anywhere
# 1. Trust Anchor: Tells AWS to trust certificates signed by your CA
# 2. Profile: Links the trust anchor to specific IAM roles
# 3. Testing: Uses aws_signing_helper to authenticate with certificates
cat > aws-commands.txt << 'EOF'
# AWS CLI Commands for IAM Roles Anywhere Setup

### **ENGINEER NOTE: Trust Anchor Creation**
# sourceType=CERTIFICATE_BUNDLE: Indicates we're uploading a CA certificate
# sourceData=file://ca.pem: Points to our CA certificate file
# This tells IAM Roles Anywhere to trust any certificate signed by this CA
# 1. Create Trust Anchor (upload CA certificate)
aws rolesanywhere create-trust-anchor \
  --name "MyCompany-OpenSSL-External-CA" \
  --source sourceType=CERTIFICATE_BUNDLE,sourceData=file://ca.pem

### **ENGINEER NOTE: Profile Creation**
# Profile links the trust anchor to specific IAM roles
# Multiple roles can be specified in the role-arns array
# This determines what AWS permissions the certificate holder gets
# 2. Create Profile (links to IAM role)
aws rolesanywhere create-profile \
  --name "MyCompany-Admin-Profile" \
  --role-arns "arn:aws:iam::ACCOUNT-ID:role/YOUR-ROLE-NAME"

# 3. Test with aws_signing_helper (replace ARNs with actual values)
./aws_signing_helper credential-process \
  --certificate client.pem \
  --private-key client.key \
  --trust-anchor-arn arn:aws:rolesanywhere:REGION:ACCOUNT-ID:trust-anchor/TRUST-ANCHOR-ID \
  --profile-arn arn:aws:rolesanywhere:REGION:ACCOUNT-ID:profile/PROFILE-ID \
  --role-arn arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME

# 4. Test with application certificate
./aws_signing_helper credential-process \
  --certificate app.pem \
  --private-key app.key \
  --trust-anchor-arn arn:aws:rolesanywhere:REGION:ACCOUNT-ID:trust-anchor/TRUST-ANCHOR-ID \
  --profile-arn arn:aws:rolesanywhere:REGION:ACCOUNT-ID:profile/PROFILE-ID \
  --role-arn arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME
EOF

echo ""
echo "Step 7: Creating Certificate Bundle for Easy Transfer..."
# Create a single file with all certificates for easy viewing
cat > certificate-bundle.txt << EOF
=== CA CERTIFICATE (Upload to Trust Anchor) ===
$(cat ca.pem)

=== CLIENT CERTIFICATE ===
$(cat client.pem)

=== APPLICATION CERTIFICATE ===
$(cat app.pem)
EOF

echo "Step 7b: Creating Zip Archive for Bulk Download..."
# Create zip file and copy to S3 using aws s3 cp filename.zip s3://bucketname/filename.zip
cd ..
zip -r iam-roles-anywhere-certificates.zip iam-roles-anywhere-certs/
cd iam-roles-anywhere-certs
echo "✅ Zip archive created: ../iam-roles-anywhere-certificates.zip"

echo ""
echo "Step 8: Certificate Usage Guide..."
echo "📁 Files created in: $(pwd)"
echo ""
echo "### **💾 CLOUDSHELL FILE ACCESS** ###"
echo ""
echo "📂 **File Location**: /home/cloudshell-user/iam-roles-anywhere-certs/"
echo ""
echo "📎 **Download Files from CloudShell:**"
echo ""
echo "🏆 **OPTION 1: Download All Files at Once (RECOMMENDED)**"
echo "  1. Click 'Actions' menu in CloudShell"
echo "  2. Select 'Download file'"
echo "  3. Enter file path: iam-roles-anywhere-certificates.zip"
echo "  4. Extract zip file on your local machine"
echo ""
echo "📝 **OPTION 2: Download Individual Files**"
echo "  1. Click 'Actions' menu in CloudShell"
echo "  2. Select 'Download file'"
echo "  3. Enter specific file paths:"
echo "     • iam-roles-anywhere-certs/ca.pem"
echo "     • iam-roles-anywhere-certs/client.pem"
echo "     • iam-roles-anywhere-certs/client.key"
echo "     • iam-roles-anywhere-certs/app.pem"
echo "     • iam-roles-anywhere-certs/app.key"
echo "     • iam-roles-anywhere-certs/aws-commands.txt"
echo "  4. Repeat for each file you need"
echo ""
echo "📝 **View Files:**"
echo "  cd iam-roles-anywhere-certs"
echo "  ls -la"
echo "  cat aws-commands.txt"
echo ""
echo "### **CERTIFICATE USAGE GUIDE** ###"
echo ""
echo "🔑 **CERTIFICATE AUTHORITY (CA) - Root of Trust**"
echo "  📄 ca.pem - CA Certificate (PUBLIC - Upload to AWS Trust Anchor)"
echo "    ✅ WHERE: AWS Console > IAM > Roles Anywhere > Trust Anchors"
echo "    ✅ PURPOSE: Tells AWS to trust certificates signed by this CA"
echo "    ✅ SECURITY: Safe to share - contains only public key"
echo ""
echo "  🔐 ca.key - CA Private Key (PRIVATE - Keep Secure!)"
echo "    ⚠️  WHERE: Secure storage only (HSM/vault in production)"
echo "    ⚠️  PURPOSE: Signs new certificates - compromise = total PKI breach"
echo "    ⚠️  SECURITY: Never share, never upload to AWS"
echo ""
echo "👤 **CLIENT CERTIFICATE - User Authentication (LTCND145794Y)**"
echo "  📄 client.pem - Client Certificate (SEMI-PUBLIC)"
echo "    ✅ WHERE: User's workstation, applications, aws_signing_helper"
echo "    ✅ PURPOSE: Proves identity to AWS IAM Roles Anywhere"
echo "    ✅ USAGE: ./aws_signing_helper --certificate client.pem"
echo ""
echo "  🔐 client.key - Client Private Key (PRIVATE - User's Secret)"
echo "    ⚠️  WHERE: User's secure storage only"
echo "    ⚠️  PURPOSE: Proves ownership of client certificate"
echo "    ⚠️  USAGE: ./aws_signing_helper --private-key client.key"
echo ""
echo "🚀 **APPLICATION CERTIFICATE - App Authentication (TestApplication)**"
echo "  📄 app.pem - Application Certificate (SEMI-PUBLIC)"
echo "    ✅ WHERE: Application servers, containers, CI/CD systems"
echo "    ✅ PURPOSE: Allows applications to authenticate to AWS"
echo "    ✅ USAGE: Embedded in application code or config"
echo ""
echo "  🔐 app.key - Application Private Key (PRIVATE - App Secret)"
echo "    ⚠️  WHERE: Application secure storage, secrets manager"
echo "    ⚠️  PURPOSE: Proves application owns the certificate"
echo "    ⚠️  USAGE: Loaded by application at runtime"
echo ""
echo "📋 **HELPER FILES**"
echo "  📄 aws-commands.txt - Ready-to-use AWS CLI commands"
echo "  📄 certificate-bundle.txt - All certificates in one file for viewing"
echo "  📄 client.csr, app.csr - Certificate signing requests (can delete)"
echo "  📄 ca.srl - CA serial number tracking (keep with CA)"
echo ""
echo "### **📦 DOWNLOAD PRIORITY** ###"
echo ""
echo "🔴 **CRITICAL (Download First):**"
echo "  📄 ca.pem - Upload to AWS Trust Anchor"
echo ""
echo "🟡 **USER CERTIFICATES:**"
echo "  📄 client.pem - Client certificate"
echo "  🔐 client.key - Client private key (keep secure)"
echo ""
echo "🟢 **APPLICATION CERTIFICATES:**"
echo "  📄 app.pem - Application certificate"
echo "  🔐 app.key - Application private key (keep secure)"
echo ""
echo "📋 **HELPER:**"
echo "  📄 aws-commands.txt - AWS CLI commands"
echo ""

echo "=== DEPLOYMENT WORKFLOW ==="
echo ""
echo "🎯 **STEP 1: AWS Setup (Run in AWS Console/CLI)**"
echo "  1a. Upload ca.pem to IAM Roles Anywhere Trust Anchor"
echo "      → AWS Console: IAM > Roles Anywhere > Trust Anchors > Create"
echo "      → AWS CLI: Use commands in aws-commands.txt"
echo ""
echo "  1b. Create Profile linking Trust Anchor to IAM Role"
echo "      → Links certificates to specific AWS permissions"
echo "      → Multiple roles can be specified for different access levels"
echo ""
echo "📦 **STEP 2: Certificate Distribution**"
echo "  2a. Client Certificate (for user LTCND145794Y):"
echo "      → Copy client.pem + client.key to user's workstation"
echo "      → Store in ~/.aws/certificates/ or secure location"
echo "      → Set proper file permissions (600 for .key files)"
echo ""
echo "  2b. Application Certificate (for TestApplication):"
echo "      → Deploy app.pem + app.key to application servers"
echo "      → Use secrets management (AWS Secrets Manager, etc.)"
echo "      → Never commit private keys to source control"
echo ""
echo "🗺️ **STEP 3: Testing & Validation**"
echo "  3a. Download aws_signing_helper from AWS"
echo "      → https://docs.aws.amazon.com/rolesanywhere/latest/userguide/credential-helper.html"
echo ""
echo "  3b. Test client certificate:"
echo "      → ./aws_signing_helper credential-process --certificate client.pem --private-key client.key ..."
echo ""
echo "  3c. Test application certificate:"
echo "      → ./aws_signing_helper credential-process --certificate app.pem --private-key app.key ..."
echo ""
echo "  3d. Verify AWS access:"
echo "      → aws sts get-caller-identity (should show assumed role)"
echo ""

echo "=== SECURITY NOTES ==="
echo "⚠️  Keep ca.key secure - it can sign new certificates"
echo "⚠️  Keep client.key and app.key secure - they provide AWS access"
echo "✅ ca.pem is safe to share - it's the public CA certificate"
echo ""

### **ENGINEER NOTE: PKI Security Model**
# This script implements a standard PKI hierarchy:
# 
# Root CA (ca.pem + ca.key)
#   ├── Client Certificate (client.pem + client.key)
#   └── Application Certificate (app.pem + app.key)
#
# Security Principles:
# 1. CA private key (ca.key) is the "root of trust" - compromise = total PKI compromise
# 2. Client private keys provide AWS access - treat like AWS access keys
# 3. CA certificate (ca.pem) is public - can be shared freely
# 4. Certificate chain validation ensures authenticity
# 5. X.509 extensions enforce proper certificate usage
#
# IAM Roles Anywhere Trust Model:
# 1. AWS trusts your CA certificate (uploaded as Trust Anchor)
# 2. Any certificate signed by your CA is trusted by AWS
# 3. Certificate subject (CN) can be used for access control
# 4. IAM roles determine actual AWS permissions

echo "### **ENGINEER NOTE: Production Considerations**"
echo "🔒 CA Key Security: Store ca.key in HSM or secure vault in production"
echo "📅 Certificate Rotation: Plan for certificate renewal before expiry"
echo "🔍 Monitoring: Set up alerts for certificate expiration"
echo "📋 Audit: Log all certificate usage for compliance"
echo "🚫 Revocation: Implement CRL or OCSP for certificate revocation"
echo ""

echo "✅ Complete! All certificates ready for IAM Roles Anywhere"
