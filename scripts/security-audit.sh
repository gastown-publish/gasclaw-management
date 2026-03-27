#!/bin/bash
# Security audit - basic checks
echo "=== Security Audit ==="

# Check for unauthorized SSH keys
echo -n "SSH keys: "
KEY_COUNT=$(ls -la /root/.ssh/authorized_keys 2>/dev/null | wc -l)
if [ "$KEY_COUNT" -gt 1 ]; then
    echo "WARNING: $KEY_COUNT authorized keys found"
else
    echo "OK"
fi

# Check open ports (basic)
echo -n "Open ports: "
netstat -tln 2>/dev/null | grep LISTEN | wc -l

# Check root login
echo -n "Root login: "
grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "defaults"

# Check password auth
echo -n "Password auth: "
grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "defaults"

# Check container env vars
echo -n "Sensitive env: "
if env | grep -i "password\|secret\|token\|key" | grep -v "HOST\|HOME\|PATH" >/dev/null; then
    echo "WARNING: sensitive vars found"
else
    echo "OK"
fi

echo "=== Audit Complete ==="