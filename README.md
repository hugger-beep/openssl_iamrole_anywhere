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

| File | Purpose | Security Level | Where It Goes | IAM Roles Anywhere Use Case |
|------|---------|----------------|---------------|-----------------------------|
| **`ca.pem`** | CA Certificate | PUBLIC | Upload to AWS Trust Anchor | Establishes trust - tells AWS to accept certificates signed by this CA |
| **`ca.key`** | CA Private Key | TOP SECRET | Secure vault only | Signs new certificates - never used directly with IAM Roles Anywhere |
| **`client.pem`** | User Certificate | SEMI-PUBLIC | User's workstation | Used with `aws_signing_helper --certificate client.pem` for user authentication |
| **`client.key`** | User Private Key | SECRET | User's secure storage | Used with `aws_signing_helper --private-key client.key` to prove certificate ownership |
| **`app.pem`** | App Certificate | SEMI-PUBLIC | Application servers | Used by applications/scripts for automated AWS authentication |
| **`app.key`** | App Private Key | SECRET | Secrets manager | Used by applications to prove ownership of app certificate |

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

## 🤔 **Do I Need Multiple Certificates?**

### **Short Answer: NO - One Certificate Per Identity**

**If `aws_signing_helper` is on the same server as your application, you only need ONE certificate pair.**

### **Certificate Usage Scenarios:**

| Scenario | Certificates Needed | Example |
|----------|-------------------|----------|
| **Application Server Only** | `app.pem` + `app.key` | Server runs automated scripts |
| **Developer Workstation Only** | `client.pem` + `client.key` | Developer's laptop |
| **Mixed Environment (Same Server)** | Choose ONE certificate | Use `app.pem` for both human and automated access |

### **Key Principle:**
- **Certificate = Identity** (not tool)
- **`aws_signing_helper` = Tool** (uses the certificate)
- **One identity = One certificate** (regardless of how many tools use it)

### **Real-World Examples:**

```bash
# Scenario 1: Application server only
./aws_signing_helper credential-process \
  --certificate app.pem \
  --private-key app.key \
  --trust-anchor-arn ... --profile-arn ... --role-arn ...

# Scenario 2: Developer workstation only  
./aws_signing_helper credential-process \
  --certificate client.pem \
  --private-key client.key \
  --trust-anchor-arn ... --profile-arn ... --role-arn ...

# Scenario 3: Same server, different purposes
# Option A: Use app certificate for everything
./aws_signing_helper --certificate app.pem --private-key app.key ...

# Option B: Use client certificate for everything
./aws_signing_helper --certificate client.pem --private-key client.key ...
```

### **Why the Script Creates Two Certificates:**
- **Different identities** for different use cases
- **`client.pem`** - Represents user LTCND145794Y
- **`app.pem`** - Represents TestApplication
- **Choose the appropriate one** for your specific use case

## 🎯 **End Result**

After running this script and following deployment steps:

- ✅ **AWS trusts your CA** (via Trust Anchor)
- ✅ **Users can authenticate** with client certificates
- ✅ **Applications can authenticate** with app certificates
- ✅ **No AWS access keys needed** - certificates provide AWS access
- ✅ **Centralized certificate management** - one CA signs all certificates

## 💡 **In Simple Terms**

**"This script builds your own certificate factory that AWS will trust, allowing you to issue certificates that work like AWS access keys but are more secure and manageable."**

### **Certificate Selection Guide:**
- **Use `app.pem/app.key`** for servers, applications, automation
- **Use `client.pem/client.key`** for individual users, developers
- **One certificate per server/identity** - not per tool or application

## 🛡️ **Certificate Security on Servers**

### **The Challenge: Certificates Must Be Accessible Yet Secure**

Since certificates need to be readable by applications, they're inherently "exposed" on servers. Here are proven methods to secure them:

### **🔐 Secrets Management Solutions (RECOMMENDED)**

#### **AWS Secrets Manager**
```bash
# Store private key in Secrets Manager
aws secretsmanager create-secret \
  --name "iam-roles-anywhere/app-private-key" \
  --secret-string file://app.key

# Store certificate in Secrets Manager
aws secretsmanager create-secret \
  --name "iam-roles-anywhere/app-certificate" \
  --secret-string file://app.pem

# Application retrieves at runtime
aws secretsmanager get-secret-value \
  --secret-id "iam-roles-anywhere/app-private-key" \
  --query SecretString --output text > /tmp/app.key
```

#### **HashiCorp Vault**
```bash
# Store in Vault
vault kv put secret/iam-roles-anywhere \
  private_key=@app.key \
  certificate=@app.pem

# Application retrieves at runtime
vault kv get -field=private_key secret/iam-roles-anywhere > /tmp/app.key
vault kv get -field=certificate secret/iam-roles-anywhere > /tmp/app.pem
```

### **🔒 File System Security (Basic Protection)**

#### **Strict File Permissions**
```bash
# Create dedicated user for application
sudo useradd -r -s /bin/false iam-app-user

# Set restrictive permissions
sudo chown iam-app-user:iam-app-user app.key app.pem
sudo chmod 600 app.key    # Owner read/write only
sudo chmod 644 app.pem    # Owner read/write, others read

# Store in protected directory
sudo mkdir -p /etc/iam-roles-anywhere/certs
sudo chown iam-app-user:iam-app-user /etc/iam-roles-anywhere/certs
sudo chmod 700 /etc/iam-roles-anywhere/certs
```

#### **Encrypted File System**
```bash
# Use encrypted partition for certificate storage
sudo cryptsetup luksFormat /dev/sdb1
sudo cryptsetup luksOpen /dev/sdb1 encrypted-certs
sudo mkfs.ext4 /dev/mapper/encrypted-certs
sudo mount /dev/mapper/encrypted-certs /etc/iam-roles-anywhere
```

### **🐳 Container Security**

#### **Docker Secrets**
```bash
# Create Docker secrets
docker secret create app-private-key app.key
docker secret create app-certificate app.pem

# Use in Docker Compose
version: '3.8'
services:
  app:
    image: myapp:latest
    secrets:
      - app-private-key
      - app-certificate
secrets:
  app-private-key:
    external: true
  app-certificate:
    external: true
```

#### **Kubernetes Secrets**
```bash
# Create Kubernetes secret
kubectl create secret generic iam-roles-anywhere-certs \
  --from-file=app.key=app.key \
  --from-file=app.pem=app.pem

# Mount as volume in pod
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    volumeMounts:
    - name: certs
      mountPath: "/etc/certs"
      readOnly: true
  volumes:
  - name: certs
    secret:
      secretName: iam-roles-anywhere-certs
      defaultMode: 0600
```

### **🔄 Runtime Security Patterns**

#### **In-Memory Only**
```python
# Python example - never write to disk
import boto3
import tempfile
import os

def get_aws_credentials():
    # Get certificate from secrets manager
    secrets = boto3.client('secretsmanager')
    
    cert_response = secrets.get_secret_value(SecretId='iam-roles-anywhere/app-certificate')
    key_response = secrets.get_secret_value(SecretId='iam-roles-anywhere/app-private-key')
    
    # Create temporary files in memory
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as cert_file:
        cert_file.write(cert_response['SecretString'])
        cert_path = cert_file.name
    
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as key_file:
        key_file.write(key_response['SecretString'])
        key_path = key_file.name
    
    try:
        # Use certificates with aws_signing_helper
        # ... authentication logic ...
        pass
    finally:
        # Always cleanup
        os.unlink(cert_path)
        os.unlink(key_path)
```

#### **Short-Lived Certificates**
```bash
# Generate certificates with shorter validity (hours instead of days)
openssl x509 -req -in app.csr -CA ca.pem -CAkey ca.key \
  -CAcreateserial -out app.pem -days 1  # 1 day instead of 365

# Implement automatic renewal
0 */6 * * * /opt/scripts/renew-certificate.sh  # Every 6 hours
```

### **🔍 Monitoring & Detection**

#### **File Access Monitoring**
```bash
# Monitor certificate file access with auditd
sudo auditctl -w /etc/iam-roles-anywhere/app.key -p rwxa -k iam-cert-access
sudo auditctl -w /etc/iam-roles-anywhere/app.pem -p rwxa -k iam-cert-access

# View access logs
sudo ausearch -k iam-cert-access
```

#### **Certificate Usage Monitoring**
```bash
# Monitor aws_signing_helper usage
ps aux | grep aws_signing_helper

# Log all certificate-based authentications
aws logs create-log-group --log-group-name iam-roles-anywhere-usage
```

### **🚨 Security Best Practices Summary**

| Security Level | Method | Pros | Cons |
|----------------|--------|------|------|
| **🥇 BEST** | AWS Secrets Manager + In-Memory | Centralized, encrypted, audited | Requires AWS API calls |
| **🥈 GOOD** | HashiCorp Vault + Runtime Retrieval | Enterprise-grade, flexible | Additional infrastructure |
| **🥉 BASIC** | File permissions + Encrypted FS | Simple, no dependencies | Still accessible to root |
| **⚠️ AVOID** | Plain files with 644 permissions | Easy to implement | Easily compromised |

### **🎯 Recommended Production Setup**

```bash
# 1. Use AWS Secrets Manager for storage
# 2. Retrieve certificates at application startup
# 3. Store in memory or temporary files only
# 4. Implement certificate rotation
# 5. Monitor all certificate access
# 6. Use short-lived certificates (1-7 days)
# 7. Implement proper cleanup on application shutdown
```

## 🔧 **Production Considerations**

- **📅 Certificate Rotation**: Plan renewal before expiry (1 year for client certs)
- **🔍 Monitoring**: Set up alerts for certificate expiration
- **📋 Audit**: Log all certificate usage for compliance
- **🚫 Revocation**: Implement CRL or OCSP for certificate revocation
- **🛡️ Certificate Security**: Use secrets management for server-side certificates
- **🔐 CA Key Security** AWS Secrets Manager**: **MANDATORY** for production certificate storage or secure vault

### **🏭 Production Secrets Manager Setup**

#### **Store Certificates in Secrets Manager**
```bash
# Store application private key
aws secretsmanager create-secret \
  --name "prod/iam-roles-anywhere/app-private-key" \
  --description "IAM Roles Anywhere application private key" \
  --secret-string file://app.key \
  --kms-key-id "arn:aws:kms:region:account:key/key-id"

# Store application certificate
aws secretsmanager create-secret \
  --name "prod/iam-roles-anywhere/app-certificate" \
  --description "IAM Roles Anywhere application certificate" \
  --secret-string file://app.pem
```

#### **Production Application Integration**
```python
#!/usr/bin/env python3
import boto3
import subprocess
import tempfile
import os
import json

class IAMRolesAnywhereAuth:
    def __init__(self, region='us-east-1'):
        self.secrets_client = boto3.client('secretsmanager', region_name=region)
    
    def get_aws_credentials(self, trust_anchor_arn, profile_arn, role_arn):
        # Get certificates from Secrets Manager
        cert_response = self.secrets_client.get_secret_value(
            SecretId='prod/iam-roles-anywhere/app-certificate'
        )
        key_response = self.secrets_client.get_secret_value(
            SecretId='prod/iam-roles-anywhere/app-private-key'
        )
        
        # Create secure temporary files
        cert_fd, cert_path = tempfile.mkstemp(suffix='.pem')
        key_fd, key_path = tempfile.mkstemp(suffix='.key')
        
        try:
            with os.fdopen(cert_fd, 'w') as f:
                f.write(cert_response['SecretString'])
            with os.fdopen(key_fd, 'w') as f:
                f.write(key_response['SecretString'])
            
            os.chmod(cert_path, 0o600)
            os.chmod(key_path, 0o600)
            
            # Use aws_signing_helper
            cmd = ['./aws_signing_helper', 'credential-process',
                   '--certificate', cert_path, '--private-key', key_path,
                   '--trust-anchor-arn', trust_anchor_arn,
                   '--profile-arn', profile_arn, '--role-arn', role_arn]
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout)
        finally:
            # Always cleanup
            for path in [cert_path, key_path]:
                if os.path.exists(path):
                    os.unlink(path)
```

### **🚨 Production Security Checklist**
- ✅ **Secrets Manager**: All certificates stored in AWS Secrets Manager
- ✅ **KMS Encryption**: Secrets encrypted with customer-managed KMS keys
- ✅ **Temporary Files**: Certificates only in secure temp files
- ✅ **Automatic Cleanup**: Always delete temporary certificate files
- ✅ **Certificate Rotation**: Automated 90-day certificate renewal

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
