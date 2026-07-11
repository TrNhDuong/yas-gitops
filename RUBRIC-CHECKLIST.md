# Checklist Argo CD – mô hình main + release tag

- [ ] `argocd-application-controller` là `1/1`.
- [ ] `yas-main-*` dùng `targetRevision: main` và namespace `yas-dev`.
- [ ] Push `main` build image bằng commit SHA và chỉ cập nhật `apps/main`.
- [ ] Git tag release có dạng `vX.Y.Z`, ví dụ `v1.2.0`.
- [ ] Tag release build image cùng tag `vX.Y.Z`.
- [ ] Release chỉ cập nhật `apps/staging`.
- [ ] Sau promote, `yas-staging-*` dùng `targetRevision: vX.Y.Z` và namespace `yas-staging`.
- [ ] Image tag staging khớp release tag.
- [ ] Dev Application đạt `Synced` và `Healthy`.
- [ ] Staging Application đạt `Synced` và `Healthy`.
- [ ] Có bằng chứng `OutOfSync -> Synced -> Healthy`.
- [ ] Feature branch không cập nhật GitOps; feature branch dùng `developer_build`.
