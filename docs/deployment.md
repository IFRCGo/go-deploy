# Deployment

ArgoCD auto-syncs both environments from the `develop` branch (see
`applications/argocd/staging.yaml` and `applications/argocd/production.yaml`,
`targetRevision: develop`). Each app-of-apps watches a different path:

- Staging: `applications/argocd/staging/`
- Production: `applications/argocd/production/`

So merging to `develop` deploys to **both** staging and production, each
from its own path. There is no separate `develop` → staging, `master` →
production split at the ArgoCD level.

`master` exists and is kept in sync with `develop` via periodic "Sync
master with develop" PRs, but nothing in this repo (no CI workflow, no
ArgoCD `Application`) currently watches or deploys from it — it functions
as a record/changelog branch, not a live deployment source.

To change what an environment deploys, edit files under
`applications/argocd/staging/` or `applications/argocd/production/` and
merge to `develop`.
