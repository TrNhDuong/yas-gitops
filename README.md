# YAS GitOps / ArgoCD manifests

Bộ file này dùng để tạo repo GitOps riêng cho đồ án YAS.

## Repo mặc định trong file

- DevOps/Helm chart repo: `https://github.com/Duong-Dung/yas_devops.git`
- GitOps repo placeholder: `https://github.com/Duong-Dung/yas-gitops.git`
- Chart branch hiện tại: `fix/k8s-minikube-yas-deploy`
- Docker Hub username: `nguyenmanhha`

> Nếu repo GitOps của bạn không tên `yas-gitops`, hãy sửa `repoURL` trong `bootstrap/dev-root.yaml`, `bootstrap/staging-root.yaml`, `bootstrap/all-roots.yaml`.

> Sau khi branch `fix/k8s-minikube-yas-deploy` được merge vào `develop`, hãy đổi toàn bộ `targetRevision` trong `apps/dev/*.yaml` và `apps/staging/*.yaml` thành `develop`.

## Cấu trúc

```text
yas-gitops-argocd/
├── bootstrap/
│   ├── dev-root.yaml
│   ├── staging-root.yaml
│   └── all-roots.yaml
├── apps/
│   ├── dev/
│   └── staging/
└── scripts/
```

## Cài ArgoCD

```bash
./scripts/install-argocd.sh
```

Lấy mật khẩu admin:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd   -o jsonpath='{.data.password}' | base64 -d
echo
```

Mở UI từ VM:

```bash
./scripts/port-forward-argocd.sh
```

Trên Windows PowerShell mở tunnel:

```powershell
cd "C:\Users\MY MSI\Desktop\Project\DevOps\VM"
ssh -i yas_key.pem -N -L 127.0.0.1:8081:127.0.0.1:8081 hd@20.24.209.134
```

Mở:

```text
https://localhost:8081
```

## Tạo secret Elasticsearch cho search

Secret Kubernetes là theo namespace, nên phải tạo cho cả dev và staging nếu deploy cả hai:

```bash
./scripts/setup-search-secret.sh yas-dev
./scripts/setup-search-secret.sh yas-staging
```

## Apply root app

Chỉ staging:

```bash
./scripts/apply-root-apps.sh staging
```

Chỉ dev:

```bash
./scripts/apply-root-apps.sh dev
```

Cả hai:

```bash
./scripts/apply-root-apps.sh all
```

## Kiểm tra

```bash
kubectl get applications -n argocd
kubectl get pods,svc,endpoints -n yas-dev
kubectl get pods,svc,endpoints -n yas-staging
```

Test qua ingress từ VM:

```bash
curl -I -H "Host: storefront.dev.yas.local.com" http://$(minikube ip)/
curl -I -H "Host: storefront.staging.yas.local.com" http://$(minikube ip)/
curl -I -H "Host: backoffice.dev.yas.local.com" http://$(minikube ip)/
curl -I -H "Host: backoffice.staging.yas.local.com" http://$(minikube ip)/
```

## Lưu ý về search

`search` cần secret `search-elasticsearch-credentials` trong từng namespace app. Nếu thiếu, pod sẽ bị:

```text
CreateContainerConfigError
Error: secret "search-elasticsearch-credentials" not found
```

Chạy lại:

```bash
./scripts/setup-search-secret.sh yas-staging
kubectl rollout restart deploy/search -n yas-staging
```

## Lưu ý về PostgreSQL

Nếu Keycloak hoặc backend báo lỗi connection tới `postgresql.postgres:5432`, kiểm tra service endpoint:

```bash
kubectl get pods,svc,endpoints -n postgres -o wide
```

Service `postgresql` phải có endpoint dạng:

```text
endpoints/postgresql   <pod-ip>:5432
```
