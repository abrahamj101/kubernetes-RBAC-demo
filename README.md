# Teleport K8s Demo 

## Overview
This project deploys a Kubernetes cluster using kind and demonstrates
Role-Based Access Control (RBAC) by deploying an Nginx application
through a restricted user (`deploy-user`) with least-privilege access.

## Architecture
```
kind cluster (teleport-demo)
└── namespace: nginx-app
    ├── Role: nginx-deployer        (scoped permissions)
    ├── RoleBinding: deploy-user    (bound to role)
    └── Deployment: nginx           (deployed BY deploy-user)
```

## Prerequisites
- Docker Desktop (WSL2 backend enabled)
- WSL2 (Ubuntu)
- kind: https://kind.sigs.k8s.io
- kubectl: https://kubernetes.io/docs/tasks/tools

## Quick Start
```bash
git clone https://github.com/abrahamj101/teleport-k8s-demo/
cd teleport
chmod +x scripts/setup.sh
./scripts/setup.sh
```

## What Gets Created
| Object | Name | Purpose |
|--------|------|---------|
| Namespace | nginx-app | Isolated environment for the app |
| Role | nginx-deployer | Least-privilege permissions |
| RoleBinding | nginx-deployer-binding | Grants role to deploy-user |
| Deployment | nginx | Nginx app deployed by deploy-user |
| Service | nginx-service | Exposes Nginx on port 80 |

## Verify the Deployment
```bash
# Confirm Nginx is running (as deploy-user)
kubectl get pods -n nginx-app --kubeconfig=deploy-user.kubeconfig

# Open in browser
kubectl port-forward service/nginx-service 8080:80 -n nginx-app
# Visit http://localhost:8080
```

## Verify Least-Privilege (RBAC Working)
```bash
# These should both return Forbidden — by design
kubectl get pods -n default --kubeconfig=deploy-user.kubeconfig
kubectl get nodes --kubeconfig=deploy-user.kubeconfig
```

## Security Discussion
This setup demonstrates both the power and limitations of native
Kubernetes RBAC with certificate-based users:

**Advantages**
- Least-privilege enforced at namespace scope
- No admin credentials needed for deployment
- Native Kubernetes — no extra tooling required

**Limitations**
- Certificates cannot be easily revoked
- kubeconfig files are static — if stolen, access is compromised
- No MFA, no audit trail, no centralized identity
- Manual certificate management does not scale

These limitations are exactly what Teleport addresses through
short-lived certificates, SSO integration, MFA, and full audit logging.

## Teardown
```bash
kind delete cluster --name teleport-demo
```
