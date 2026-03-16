# Set container vars
# Example
REPO="newrelic/infrastructure-k8s"
TAG="2.13.15-1.1"

REPO="prometheus/node-exporter"
TAG="v1.5.0"

REPO="twistlock/private"
TAG="defender_33_00_169-linux-amd64"

# Set repo vars
REGISTRY="docker.foo.net"
USER="svcfoo"
TOKEN="DUMMYTOKEN"
AUTH=$(printf "%s:%s" "$USER" "$TOKEN" | base64 -w0)

curl -I \
    -H "Authorization: Basic $AUTH" \
    https://${REGISTRY}/v2/


curl -s \
    -H "Authorization: Basic $AUTH" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    https://${REGISTRY}/v2/${REPO}/manifests/${TAG} \
    | tee manifest.json

CONFIG_DIGEST=$(jq -r '.config.digest' manifest.json)

jq -r '.layers[].digest' manifest.json | while read -r DIGEST; do
    echo "Pulling layer $DIGEST"
    curl -f \
        -H "Authorization: Basic $AUTH" \
        https://${REGISTRY}/v2/${REPO}/blobs/${DIGEST} \
        -o "${DIGEST#sha256:}.tar.gz" || break
done
