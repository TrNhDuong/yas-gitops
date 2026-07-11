# YAS GitOps – Argo CD theo `main` và Git release tag

Bộ cấu hình này bám đúng mô hình của đề:

```text
main thay đổi
  -> CI build image bằng commit SHA
  -> cập nhật yas-gitops/apps/main
  -> Argo CD deploy vào yas-dev

main được gắn tag release vX.Y.Z
  -> CI build/push image :vX.Y.Z
  -> cập nhật yas-gitops/apps/staging
  -> Argo CD deploy release vào yas-staging
```

Không cần branch `staging`. Feature branch không tự động đi vào hai môi trường này; feature branch dùng job `developer_build` và namespace riêng.

## 1. Cấu trúc

```text
apps/main/       desired state của yas-dev
apps/staging/    desired state của yas-staging
bootstrap/       AppProject và hai root Application
scripts/         cài, migrate, kiểm tra và promote release
```

Tên Application được giữ là `yas-main-*` để tránh đổi lại các Application đang có trên cluster. Ý nghĩa thực tế:

```text
yas-main-*     -> source main        -> yas-dev
yas-staging-*  -> source release tag -> yas-staging
```

Hai root Application luôn đọc branch `main` của repo `yas-gitops`:

```text
yas-main-root     -> yas-gitops/main/apps/main
yas-staging-root  -> yas-gitops/main/apps/staging
```

## 2. Tại sao staging ban đầu vẫn là `targetRevision: main`?

Bộ ZIP không thể đoán trước release tag nào đã tồn tại. Vì vậy staging được bootstrap từ `main` để không còn lỗi:

```text
unable to resolve 'staging' to a commit SHA
```

Khi tạo release `v1.2.0`, CI cập nhật riêng Application tương ứng thành:

```yaml
source:
  targetRevision: v1.2.0
helm:
  parameters:
    - name: backend.image.tag
      value: v1.2.0
```

Như vậy chart và image của staging đều được khóa tại cùng một release.

## 3. Đưa repo GitOps lên GitHub

Thay nội dung repo `TrNhDuong/yas-gitops` bằng thư mục `yas-gitops` trong package, giữ lại `.git`:

```bash
cd ~/yas-gitops
git switch main
git pull origin main

# copy nội dung package/yas-gitops vào repo này

git add .
git commit -m "fix(argocd): use main for dev and release tags for staging"
git push origin main
```

Sau khi push, trên VM:

```bash
cd ~/yas-gitops
git pull origin main
chmod +x scripts/*
```

## 4. Cài hoặc sửa Argo CD

```bash
./scripts/install-argocd.sh
```

Bắt buộc:

```bash
kubectl get sts argocd-application-controller -n argocd
```

Kết quả phải là `1/1`.

## 5. Migration cluster hiện tại

Nếu cluster từng có `yas-dev-*` cũ:

```bash
./scripts/migrate-existing-cluster.sh
./scripts/migrate-existing-cluster.sh --yes
```

Script gỡ finalizer trước khi xóa Application cũ, nên không chủ động xóa workload trong `yas-dev`.

Nếu không cần migration:

```bash
./scripts/apply-root-apps.sh all
```

Sau đó refresh:

```bash
kubectl annotate applications.argoproj.io -n argocd --all \
  argocd.argoproj.io/refresh=hard --overwrite
```

## 6. Cấu hình CI trong `yas_devops`

Package có thư mục `yas-devops-patch`. Chép action vào:

```text
.github/workflows/actions/gitops-update-image-tag/action.yaml
```

Workflow mẫu tax:

```text
.github/workflows/tax-ci-main-release-example.yaml
```

Repository settings cần:

```text
Variable: DOCKERHUB_USERNAME
Secret:   DOCKERHUB_TOKEN
Secret:   GITOPS_PAT
```

Routing trong action:

```text
branch main  -> apps/main
Git tag v*   -> apps/staging
branch khác  -> skip GitOps
```

## 7. Luồng dev

Push code vào `main`:

```bash
git switch main
git add .
git commit -m "demo: update tax on dev"
git push origin main
```

CI phải:

1. build image `yas-tax:<full-commit-sha>`;
2. push Docker Hub;
3. sửa `apps/main/10-tax.yaml`;
4. commit/push repo GitOps;
5. để Argo CD tự sync `yas-main-tax` vào `yas-dev`.

Không gọi `helm upgrade`, `kubectl set image` hoặc `argocd app sync` trong luồng GitOps.

## 8. Luồng release staging

Chỉ tạo tag khi commit trên main đã ổn định:

```bash
git switch main
git pull --ff-only origin main
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

Mỗi service workflow được cấu hình tag event sẽ:

1. build/push image `:<release-tag>`;
2. cập nhật đúng file trong `apps/staging`;
3. đặt `targetRevision` và image tag cùng bằng `v1.2.0`;
4. Argo CD triển khai vào `yas-staging`.

Không phải mọi Docker image tự có tag `v1.2.0`; workflow phải build hoặc gắn và push tag đó.

Nếu tất cả release images đã có sẵn, có thể promote thủ công toàn bộ manifest:

```bash
python3 scripts/promote-release.py --tag v1.2.0

git add apps/staging
git commit -m "release: promote v1.2.0 to staging"
git push origin main
```

Chỉ chạy lệnh trên khi tất cả image tương ứng `:v1.2.0` thực sự tồn tại.

## 9. Kiểm tra revision tồn tại

```bash
./scripts/check-source-revisions.sh
```

Kiểm tra thêm release tag:

```bash
RELEASE_TAG=v1.2.0 ./scripts/check-source-revisions.sh
```

## 10. Kiểm tra Argo CD

Trước release đầu tiên:

```bash
./scripts/check-apps.sh
```

Sau khi đã promote release:

```bash
REQUIRE_RELEASE_TAG=true ./scripts/check-apps.sh
```

Hoặc xem trực tiếp:

```bash
kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='NAME:.metadata.name,REVISION:.spec.source.targetRevision,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

Kết quả sau release ví dụ:

```text
yas-main-tax       main      yas-dev       Synced  Healthy
yas-staging-tax    v1.2.0    yas-staging   Synced  Healthy
```

Root staging vẫn hiện `main`, vì nó đọc manifest từ branch main của repo GitOps; child staging mới hiện release tag.

## 11. Search secret

Secret phải có trong từng namespace:

```bash
export ELASTIC_USERNAME='<username>'
export ELASTIC_PASSWORD='<password>'
./scripts/setup-search-secret.sh yas-dev
./scripts/setup-search-secret.sh yas-staging
```

Không commit mật khẩu vào Git.

## 12. Khi Application chưa Healthy

`Synced` chỉ nghĩa là live state khớp Git. Pod chưa Ready có thể khiến Health là `Progressing` hoặc `Degraded`.

```bash
kubectl get pods -n yas-dev
kubectl get pods -n yas-staging
kubectl get events -n yas-staging --sort-by=.lastTimestamp | tail -80
kubectl describe application yas-staging-tax -n argocd
```

Phải sửa readiness, Secret, ConfigMap hoặc dependency; không cấu hình giả health để đổi màu.

## 13. Bằng chứng khi chấm

Cần quay/chụp hai luồng độc lập:

```text
Push main
-> Docker image commit SHA
-> chỉ apps/main đổi
-> yas-dev OutOfSync -> Synced -> Healthy
```

```text
Push Git tag v1.2.0
-> Docker images v1.2.0
-> chỉ apps/staging đổi
-> yas-staging OutOfSync -> Synced -> Healthy
```

Điều này đáp ứng phần nâng cao Argo CD quản lý `dev` và `staging`, trong đó dev nhận main liên tục và staging nhận bản release được gắn tag.
