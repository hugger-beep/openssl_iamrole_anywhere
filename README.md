# IAM Roles Anywhere - OpenSSL PKI Setup

## 🎯 **High-Level Overview**

This bash script creates a **complete Public Key Infrastructure (PKI)** for AWS IAM Roles Anywhere using OpenSSL as an External Trust Anchor.

### 🏗️ **The Big Picture:**
```
Your OpenSSL CA → Signs Certificates → AWS Trusts Your CA → Certificate = AWS Access
```

## 📋 **What the Script Does (8 Steps)**

### **Certificate Generation (Steps 1-3)**
- **🏛️ Creates Certificate Authority (CA)** - Your own "root of trust"
- **👤 Creates Client Certificate** - For user authentication (LTCND145794Y)
- **🚀 Creates Application Certificate** - For automated systems (TestApplication)

### **Validation (Steps 4-5)**
- **✅ Verifies Certificate Chain** - Ensures certificates are properly signed
- **📊 Shows Certificate Details** - Subject, issuer, expiration dates

### **AWS Integration (Steps 6-8)**
- **📝 Generates AWS CLI Commands** - Ready-to-use commands for setup
- **📦 Creates Certificate Bundle** - All certificates in one file
- **📋 Provides Usage Guide** - Complete deployment instructions

## 🔑 **Key Files Generated**

| File | Purpose | Security Level | Where It Goes |
|------|---------|----------------|---------------|
| **`ca.pem`** | CA Certificate | PUBLIC | Upload to AWS Trust Anchor |
| **`ca.key`** | CA Private Key | TOP SECRET | Secure vault only |
| **`client.pem`** | User Certificate | SEMI-PUBLIC | User's workstation |
| **`client.key`** | User Private Key | SECRET | User's secure storage |
| **`app.pem`** | App Certificate | SEMI-PUBLIC | Application servers |
| **`app.key`** | App Private Key | SECRET | Secrets manager |

## 🚀 **Quick Start**

### **1. Run the Script**
```bash
# In AWS CloudShell (recommended)
chmod +x openssl.sh
./openssl.sh
```

### **2. Upload CA to AWS**
```bash
# Use generated commands in aws-commands.txt
aws rolesanywhere create-trust-anchor \
  --name "TI-OpenSSL-External-CA" \
  --source sourceType=CERTIFICATE_BUNDLE,sourceData=file://ca.pem
```

### **3. Test Authentication**
```bash
# Download aws_signing_helper first
./aws_signing_helper credential-process \
  --certificate client.pem \
  --private-key client.key \
  --trust-anchor-arn arn:aws:rolesanywhere:REGION:ACCOUNT:trust-anchor/ID \
  --profile-arn arn:aws:rolesanywhere:REGION:ACCOUNT:profile/ID \
  --role-arn arn:aws:iam::ACCOUNT:role/ROLE-NAME
```

## 🌐 **Where to Run**

| Environment | Status | Notes |
|-------------|--------|-------|
| **AWS CloudShell** | ✅ RECOMMENDED | Pre-installed tools, secure environment |
| **Linux/macOS Terminal** | ✅ SUPPORTED | Requires OpenSSL and AWS CLI |
| **Windows Git Bash** | ❌ NOT RECOMMENDED | Path conversion issues |

## 🔒 **Security Model**

### **PKI Hierarchy:**
```
Root CA (ca.pem + ca.key)
├── Client Certificate (client.pem + client.key)
└── Application Certificate (app.pem + app.key)
```

### **Trust Flow:**
1. **AWS trusts your CA** (via Trust Anchor)
2. **CA signs client certificates**
3. **AWS trusts any certificate signed by your CA**
4. **Certificate holder gets AWS access**

## 📦 **Certificate Distribution**

### **Client Certificate (User Access)**
```bash
# Copy to user workstation
scp client.pem client.key user@workstation:~/.aws/certificates/
chmod 600 ~/.aws/certificates/client.key
```

### **Application Certificate (Automated Access)**
```bash
# Deploy to application servers
# Use AWS Secrets Manager or similar for private keys
aws secretsmanager create-secret \
  --name "app-certificate-key" \
  --secret-string file://app.key
```

## 🎯 **End Result**

After running this script and following deployment steps:

- ✅ **AWS trusts your CA** (via Trust Anchor)
- ✅ **Users can authenticate** with client certificates
- ✅ **Applications can authenticate** with app certificates
- ✅ **No AWS access keys needed** - certificates provide AWS access
- ✅ **Centralized certificate management** - one CA signs all certificates

## 💡 **In Simple Terms**

**"This script builds your own certificate factory that AWS will trust, allowing you to issue certificates that work like AWS access keys but are more secure and manageable."**

## 🔧 **Production Considerations**

- **🔒 CA Key Security**: Store `ca.key` in HSM or secure vault
- **📅 Certificate Rotation**: Plan renewal before expiry (1 year for client certs)
- **🔍 Monitoring**: Set up alerts for certificate expiration
- **📋 Audit**: Log all certificate usage for compliance
- **🚫 Revocation**: Implement CRL or OCSP for certificate revocation

## 📚 **Related Files**

- **`openssl.sh`** - Main script that generates all certificates
- **`aws-commands.txt`** - Generated AWS CLI commands (created by script)
- **`certificate-bundle.txt`** - All certificates in one file (created by script)
- **`openssl_issue.md`** - Troubleshooting guide for common OpenSSL issues

## 🆘 **Troubleshooting**

### **Common Issues:**
- **"Untrusted certificate"** → Verify certificate chain with `openssl verify -CAfile ca.pem client.pem`
- **"Path conversion errors"** → Use AWS CloudShell instead of Windows Git Bash
- **"Permission denied"** → Set proper file permissions: `chmod 600 *.key`

### **Verification Commands:**
```bash
# Verify certificate chain
openssl verify -CAfile ca.pem client.pem

# Check certificate details
openssl x509 -noout -text -in client.pem

# Test AWS access
aws sts get-caller-identity
```
