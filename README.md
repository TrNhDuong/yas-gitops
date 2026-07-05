# YAS GitOps / ArgoCD manifests

Bộ file này dùng để tạo repo GitOps riêng cho đồ án YAS.

## Repo mặc định trong file

- DevOps/Helm chart repo: `https://github.com/Duong-Dung/yas_devops.git`
- GitOps repo: `https://github.com/Duong-Dung/yas-gitops.git`
- Chart branch hiện tại: `fix/k8s-minikube-yas-deploy`
- Docker Hub username: `nguyenmanhha`

Sau khi branch `fix/k8s-minikube-yas-deploy` được merge vào `develop`, đổi toàn bộ `targetRevision` trong `apps/dev/*.yaml` và `apps/staging/*.yaml` thành `develop`.

## Nội dung đã chỉnh trong bản này

- Root app đã trỏ đúng repo GitOps: `https://github.com/Duong-Dung/yas-gitops.git`.
- Script `install-argocd.sh` đã đổi sang `kubectl apply --server-side --force-conflicts` để tránh lỗi CRD annotation quá dài.
- Script `install-argocd.sh` tự patch `argocd-cm` với `application.instanceLabelKey=argocd.argoproj.io/instance`.
- Các app Helm đều có `helm.releaseName` để giữ release name như khi deploy thủ công bằng Helm.
- Có script `configure-argocd-tracking.sh` nếu ArgoCD đã được cài trước đó và cần patch lại tracking label.
- `search` có cấu hình Elasticsearch env và dùng Secret `search-elasticsearch-credentials` theo từng namespace.

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

## Cài hoặc cập nhật ArgoCD

```bash
./scripts/install-argocd.sh
```

Nếu ArgoCD đã cài từ trước, vẫn có thể chạy script này để update bằng server-side apply và patch tracking label.

Nếu chỉ muốn patch tracking label:

```bash
./scripts/configure-argocd-tracking.sh
```

Lấy mật khẩu admin:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
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

## Kiểm tra ArgoCD

```bash
kubectl get applications -n argocd
kubectl describe application yas-staging-root -n argocd | tail -80
```

Nếu app `OutOfSync`, có thể refresh:

```bash
kubectl annotate applications -n argocd --all \
  argocd.argoproj.io/refresh=hard --overwrite
```

## Kiểm tra pods và endpoints

```bash
kubectl get pods,svc,endpoints -n yas-dev
kubectl get pods,svc,endpoints -n yas-staging
```

Các service backend như `product`, `cart`, `search`, `storefront-bff` phải có endpoints. Nếu pod Running nhưng endpoint `<none>`, kiểm tra `helm.releaseName` và ArgoCD tracking label.

Test qua ingress từ VM:

```bash
curl -I -H "Host: storefront.dev.yas.local.com" http://$(minikube ip)/
curl -I -H "Host: storefront.staging.yas.local.com" http://$(minikube ip)/
curl -I -H "Host: backoffice.dev.yas.local.com" http://$(minikube ip)/
curl -I -H "Host: backoffice.staging.yas.local.com" http://$(minikube ip)/
```

## Lưu ý về Helm release name

Mỗi ArgoCD Application có tên dạng `yas-staging-product`, nhưng Helm release name cần giữ là `product` để không làm lệch selector label của Service/Pod.

Ví dụ:

```yaml
source:
  path: k8s/charts/product
  helm:
    releaseName: "product"
```

Nếu thiếu `releaseName`, Service có thể chọn sai label và endpoints bị `<none>` dù pod vẫn `Running`.

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
