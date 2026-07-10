# YAS GitOps – cấu hình Argo CD cho Project 2

Bản này được chỉnh để đáp ứng trực tiếp tiêu chí:

> Argo CD phát hiện riêng branch `main` và `staging`; các Application đạt `Synced` và `Healthy`.

## 1. Kiến trúc cuối

```text
yas_devops/main
  -> CI build image main-<sha>
  -> commit tag vào yas-gitops/apps/main
  -> Argo CD yas-main-*
  -> namespace runtime yas-dev

yas_devops/staging
  -> CI build image staging-<sha>
  -> commit tag vào yas-gitops/apps/staging
  -> Argo CD yas-staging-*
  -> namespace runtime yas-staging
```

GitOps repo chỉ cần branch `main`. Hai thư mục `apps/main` và `apps/staging` giữ trạng thái mong muốn của hai môi trường. Các child Application mới là nơi theo dõi hai branch khác nhau của source repo.

`main` dùng lại namespace `yas-dev` hiện có để không phải chạy thêm một bản sao đầy đủ trong `yas-main`. Tên Application vẫn là `yas-main-*` và `targetRevision` vẫn là `main`, nên lúc chấm có thể nhìn rõ routing branch. Pipeline Helm trực tiếp phải dùng `yas-direct-dev` và `yas-direct-staging`, không dùng `yas-dev`/`yas-staging`, để tránh tranh quyền với Argo CD.

## 2. Những lỗi của cấu hình cũ đã được sửa

- GitOps repo URL đổi thành `https://github.com/TrNhDuong/yas-gitops.git`.
- Không còn dùng `fix/k8s-minikube-yas-deploy` cho cả hai môi trường.
- `apps/main/*` theo dõi `targetRevision: main`.
- `apps/staging/*` theo dõi `targetRevision: staging`.
- Application main đổi tên thành `yas-main-*`, không còn `yas-dev-*`.
- Root apps là `yas-main-root` và `yas-staging-root`.
- Auto-sync, prune, self-heal, retry và sync waves được giữ/bổ sung.
- `helm.releaseName` được giữ nguyên để Service selector và Helm labels không đổi.
- Script cài đặt luôn đưa `argocd-application-controller` về `1/1`.
- Có migration script để bỏ Application cũ nhưng giữ nguyên workload đang chạy trong `yas-dev`.
- Có script update image theo branch, tránh việc push `main` cập nhật nhầm staging hoặc ngược lại.

## 3. Điều kiện bắt buộc trước khi apply

Source repo `TrNhDuong/yas_devops` phải có cả hai branch `main` và `staging`.

Hiện tại cần tạo `staging` từ `main` nếu branch này chưa tồn tại:

```bash
cd yas_devops
git switch main
git pull origin main
git switch -c staging
git push -u origin staging
```

Kiểm tra:

```bash
./scripts/check-source-branches.sh
```

## 4. Đưa bộ file này lên GitOps repo

Giải nén, sau đó thay nội dung repo `yas-gitops` bằng nội dung thư mục này:

```bash
cd yas-gitops
git switch main
git pull origin main

# Copy nội dung bản fixed vào đây, rồi:
git add .
git commit -m "fix(argocd): route main and staging independently"
git push origin main
```

Phải push lên GitHub trước khi apply root app, vì root app đọc manifest từ GitHub.

## 5. Cài hoặc sửa Argo CD trên VM

```bash
chmod +x scripts/*.sh
./scripts/install-argocd.sh
```

Script này:

1. Cài/cập nhật Argo CD bằng server-side apply.
2. Scale `argocd-application-controller` thành 1 replica.
3. Chờ tất cả component sẵn sàng.
4. Đặt tracking label key ổn định.

Kiểm tra bắt buộc:

```bash
kubectl get sts argocd-application-controller -n argocd
```

Kết quả phải là:

```text
NAME                            READY
argocd-application-controller   1/1
```

## 6. Tạo secret cho Search

Secret là theo namespace nên cần tạo ở cả main runtime (`yas-dev`) và staging:

```bash
export ELASTIC_USERNAME='<username>'
export ELASTIC_PASSWORD='<password>'

./scripts/setup-search-secret.sh yas-dev
./scripts/setup-search-secret.sh yas-staging
```

Không commit password thật vào Git.

## 7. Migration cluster hiện tại

Cluster hiện tại có các Application `yas-dev-*` theo branch fix. Migration sẽ xóa các Application CR cũ nhưng bỏ finalizer trước, do đó Deployment/Service/Pod đang chạy trong `yas-dev` được giữ lại. Sau đó `yas-main-*` sẽ nhận quản lý các resource đó.

Xem kế hoạch mà chưa thay đổi cluster:

```bash
./scripts/migrate-existing-cluster.sh
```

Thực thi:

```bash
./scripts/migrate-existing-cluster.sh --yes
```

Theo dõi:

```bash
watch -n 2 'kubectl get applications -n argocd'
```

Không dùng `kubectl delete namespace yas-dev`.

## 8. Apply mới từ đầu

Nếu không cần migration:

```bash
./scripts/apply-root-apps.sh all
```

Có thể apply riêng:

```bash
./scripts/apply-root-apps.sh main
./scripts/apply-root-apps.sh staging
```

## 9. Kết quả đúng để chụp khi chấm

```bash
./scripts/check-apps.sh
```

Hoặc:

```bash
kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='NAME:.metadata.name,BRANCH:.spec.source.targetRevision,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

Kết quả child Application phải có dạng:

```text
yas-main-tax          main       yas-dev       Synced   Healthy
yas-main-customer     main       yas-dev       Synced   Healthy
yas-staging-tax       staging    yas-staging   Synced   Healthy
yas-staging-customer  staging    yas-staging   Synced   Healthy
```

Hai root app đều theo dõi branch `main` của **GitOps repo**:

```text
yas-main-root         main       argocd        Synced   Healthy
yas-staging-root      main       argocd        Synced   Healthy
```

Điều này đúng. Root app đọc hai thư mục trong GitOps repo; child app mới đọc branch `main` hoặc `staging` của source/chart repo.

## 10. CI cập nhật image đúng môi trường

Thư mục `ci-example` có workflow mẫu cho tax. Cần cấu hình trong repo `yas_devops`:

- Variable `DOCKERHUB_USERNAME`.
- Secret `DOCKERHUB_TOKEN`.
- Secret `GITOPS_PAT` có quyền ghi repo `yas-gitops`.

Copy workflow:

```bash
cp ci-example/tax-gitops.yml \
  ../yas_devops/.github/workflows/tax-gitops.yml
```

Workflow dùng tag bất biến:

```text
main-<short-sha>
staging-<short-sha>
```

Sau khi build, workflow clone GitOps repo và chạy:

```bash
python scripts/update-image-tag.py \
  --branch main \
  --service tax \
  --tag main-a1b2c3d
```

hoặc:

```bash
python scripts/update-image-tag.py \
  --branch staging \
  --service tax \
  --tag staging-d4e5f6a
```

Script chỉ sửa một file trong đúng thư mục branch tương ứng.

## 11. Kịch bản demo Argo CD 2 điểm

### Staging

```bash
cd yas_devops
git switch staging
# sửa nhỏ tax hoặc customer
git add .
git commit -m "demo: staging deployment"
git push origin staging
```

Chứng minh theo thứ tự:

```text
GitHub Actions success
Docker Hub có tag staging-<sha>
yas-gitops chỉ đổi apps/staging/<service>.yaml
Argo CD staging: OutOfSync -> Synced
Health: Progressing -> Healthy
yas-main-* không đổi
```

### Main

```bash
git switch main
git merge staging
git push origin main
```

Chứng minh:

```text
Docker Hub có tag main-<sha>
yas-gitops chỉ đổi apps/main/<service>.yaml
Argo CD main: OutOfSync -> Synced -> Healthy
yas-staging-* không đổi
```

## 12. Pipeline không dùng Argo CD

Rubric này là mục khác. Dùng workflow `ci-example/direct-cd-template.yml` và deploy trực tiếp bằng Helm vào:

```text
yas-direct-dev
yas-direct-staging
```

Không deploy trực tiếp vào `yas-dev` hoặc `yas-staging`, vì Argo CD đang self-heal hai namespace đó.

## 13. Truy cập UI

Trên VM:

```bash
./scripts/port-forward-argocd.sh
```

Từ máy cá nhân tạo SSH tunnel tới cổng 8081 trên VM, sau đó mở:

```text
https://localhost:8081
```

## 14. Khi Application không Healthy

Xem trạng thái thật sau khi controller đã chạy:

```bash
kubectl describe application yas-staging-tax -n argocd
kubectl get pods -n yas-staging
kubectl get events -n yas-staging --sort-by=.lastTimestamp | tail -50
```

Application `Synced` nhưng pod `0/1` thường sẽ chuyển `Progressing` hoặc `Degraded` sau khi controller reconcile. Sửa readiness/dependency của workload, không chỉnh giả health trong Argo CD.
