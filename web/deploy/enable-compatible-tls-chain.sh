#!/bin/bash
# Run on VPS after certbot issues tryan.app / api.tryan.app certs.
# Fixes Windows / legacy browsers that fail on the short LE YR chain (missing X1 cross-sign).
set -euo pipefail

CROSS=/etc/letsencrypt/certs/root-yr-by-x1.pem
mkdir -p /etc/letsencrypt/certs /etc/letsencrypt/renewal-hooks/deploy

curl -fsSL https://letsencrypt.org/certs/gen-y/root-yr-by-x1.pem -o "$CROSS"

build_compat() {
  local name=$1
  local live=/etc/letsencrypt/live/$name
  local compat=/etc/letsencrypt/compatible/$name
  mkdir -p "$compat"
  awk 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} n==1{flag=1} flag{print} /END CERTIFICATE/{if(n==1) exit}' \
    "$live/chain.pem" > "$compat/intermediate.pem"
  cat "$live/cert.pem" "$compat/intermediate.pem" "$CROSS" > "$compat/fullchain.pem"
}

for domain in tryan.app api.tryan.app; do
  [[ -d /etc/letsencrypt/live/$domain ]] && build_compat "$domain"
done

cat > /etc/letsencrypt/renewal-hooks/deploy/compatible-chain.sh << 'HOOK'
#!/bin/bash
set -euo pipefail
CROSS=/etc/letsencrypt/certs/root-yr-by-x1.pem
[[ -f "$CROSS" ]] || curl -fsSL https://letsencrypt.org/certs/gen-y/root-yr-by-x1.pem -o "$CROSS"
RENEWED="${RENEWED_LINEAGE:-}"
[[ -n "$RENEWED" ]] || exit 0
name=$(basename "$RENEWED")
[[ "$name" == "tryan.app" || "$name" == "api.tryan.app" ]] || exit 0
compat=/etc/letsencrypt/compatible/$name
mkdir -p "$compat"
awk 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} n==1{flag=1} flag{print} /END CERTIFICATE/{if(n==1) exit}' \
  "$RENEWED/chain.pem" > "$compat/intermediate.pem"
cat "$RENEWED/cert.pem" "$compat/intermediate.pem" "$CROSS" > "$compat/fullchain.pem"
HOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/compatible-chain.sh

for conf in /etc/letsencrypt/renewal/tryan.app.conf /etc/letsencrypt/renewal/api.tryan.app.conf; do
  [[ -f "$conf" ]] && grep -q preferred_chain "$conf" || \
    sed -i '/^\[renewalparams\]/a preferred_chain = ISRG Root X1' "$conf"
done

echo "Compatible chains built under /etc/letsencrypt/compatible/"
echo "Point nginx ssl_certificate at compatible/*/fullchain.pem (see nginx-tryan.app.conf)."
