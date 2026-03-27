#!/bin/bash
set -e

echo "=== Teleport K8s Demo Setup ==="

# 1. Create kind cluster
echo "[1/6] Creating kind cluster..."
kind create cluster --name teleport-demo

# 2. Apply namespace and RBAC
echo "[2/6] Applying namespace and RBAC..."
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/role.yaml
kubectl apply -f manifests/rolebinding.yaml

# 3. Generate deploy-user certificates
echo "[3/6] Generating deploy-user certificates..."
mkdir -p certs
openssl genrsa -out certs/deploy-user.key 2048
openssl req -new \
  -key certs/deploy-user.key \
  -out certs/deploy-user.csr \
  -subj "/CN=deploy-user/O=nginx-team"

# 4. Copy cluster CA and sign certificate
echo "[4/6] Signing deploy-user certificate with cluster CA..."
docker cp teleport-demo-control-plane:/etc/kubernetes/pki/ca.crt certs/ca.crt
docker cp teleport-demo-control-plane:/etc/kubernetes/pki/ca.key certs/ca.key
openssl x509 -req \
  -in certs/deploy-user.csr \
  -CA certs/ca.crt \
  -CAkey certs/ca.key \
  -CAcreateserial \
  -out certs/deploy-user.crt \
  -days 365

# 5. Build deploy-user kubeconfig
echo "[5/6] Building deploy-user kubeconfig..."
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl config set-cluster teleport-demo \
  --certificate-authority=certs/ca.crt \
  --server=$CLUSTER_SERVER \
  --embed-certs=true \
  --kubeconfig=deploy-user.kubeconfig
kubectl config set-credentials deploy-user \
  --client-certificate=certs/deploy-user.crt \
  --client-key=certs/deploy-user.key \
  --embed-certs=true \
  --kubeconfig=deploy-user.kubeconfig
kubectl config set-context deploy-user-context \
  --cluster=teleport-demo \
  --namespace=nginx-app \
  --user=deploy-user \
  --kubeconfig=deploy-user.kubeconfig
kubectl config use-context deploy-user-context \
  --kubeconfig=deploy-user.kubeconfig

# 6. Deploy Nginx as deploy-user
echo "[6/6] Deploying Nginx as deploy-user..."
kubectl apply -f manifests/nginx-deployment.yaml \
  --kubeconfig=deploy-user.kubeconfig

echo ""
echo "=== Setup Complete ==="
echo "Run this to verify Nginx is running:"
echo "  kubectl get pods -n nginx-app --kubeconfig=deploy-user.kubeconfig"
echo ""
echo "Run this to open Nginx in your browser:"
echo "  kubectl port-forward service/nginx-service 8080:80 -n nginx-app"
echo "  Then visit: http://localhost:8080"
