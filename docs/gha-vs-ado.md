# GitHub Actions vs Azure DevOps — Detailed Comparison

> Written from hands-on experience building the same CI/CD pipeline on both platforms.
> P4 = Azure DevOps. P5 = GitHub Actions. Same outcome, different patterns.

## Core Concepts Mapping

| Concept | Azure DevOps | GitHub Actions |
|---|---|---|
| Pipeline definition | `azure-pipelines.yml` (single file) | `.github/workflows/*.yml` (multiple files) |
| Reusable jobs | YAML templates (`template:`) | Reusable workflows (`workflow_call`) |
| Reusable steps | Step templates | Composite actions (`action.yml`) |
| Variables per environment | Variable templates (`.yml` files) | GitHub Environment secrets/variables |
| Secret storage | Variable groups + Key Vault integration | GitHub Secrets (repo/org/environment) |
| Approval gates | ADO Environments with approval checks | GitHub Environments with protection rules |
| OIDC authentication | Service connection (built-in, UI setup) | `azure/login@v2` + federated credential (Terraform) |
| Artifacts | `PublishPipelineArtifact` / `DownloadPipelineArtifact` | `actions/upload-artifact` / `actions/download-artifact` |
| Conditions | `condition: eq(variables['Build.SourceBranch'], ...)` | `if: github.ref == 'refs/heads/main'` |
| Multi-repo checkout | `resources: repositories:` block | `actions/checkout` with `repository:` parameter |
| Manual trigger | `trigger: none` + run manually in UI | `workflow_dispatch` with typed inputs |
| Agent pools | Microsoft-hosted / self-hosted agents | GitHub-hosted / self-hosted runners |
| Marketplace | Task extensions (Azure DevOps Marketplace) | Actions (GitHub Marketplace) |
| Parallel jobs | Free tier: 1 parallel job | Free tier: 20 concurrent jobs (public repos) |

## Authentication — The Biggest Difference

### Azure DevOps
```
1. Create Service Connection in ADO UI (or Terraform)
2. Select "Workload Identity Federation (automatic)"
3. ADO handles App Registration + Federated Credential automatically
4. Use in pipeline: azureSubscription: 'connection-name'
5. Done — OIDC is built into the platform
```

### GitHub Actions
```
1. Create App Registration in Entra ID (Terraform)
2. Create Federated Credential pointing to GitHub repo (Terraform)
3. Assign role to Service Principal (Terraform)
4. Store client_id, tenant_id, subscription_id as GitHub Secrets
5. Every job needs:
   permissions:
     id-token: write
   steps:
     - uses: azure/login@v2
       with:
         client-id: ${{ secrets.AZURE_CLIENT_ID }}
         ...
```

**ADO advantage:** OIDC is native — one UI click. No Terraform needed.
**GHA advantage:** The trust is Terraform-managed infrastructure as code. Auditable, version-controlled, reproducible. The explicit setup teaches you exactly how OIDC works.

## Reusable Components — Different Models

### ADO: YAML Templates
Templates are **included** into the calling pipeline. They share the calling job's workspace and variables.

```yaml
# Calling pipeline
stages:
  - template: templates/build-stage.yml
    parameters:
      imageName: my-app
```

### GHA: Reusable Workflows
Reusable workflows run as **separate jobs** with their own runner and clean workspace.

```yaml
# Calling workflow
jobs:
  build:
    uses: ./.github/workflows/reusable/build.yml
    with:
      image-name: my-app
    secrets: inherit    # MUST pass explicitly
```

**Key difference:** GHA reusable workflows need their own `actions/checkout` because they get a clean workspace. ADO templates inherit the calling job's checkout.

### GHA: Composite Actions (no ADO equivalent)
Composite actions inject steps into the calling job's runner — closer to ADO step templates but packaged as versioned actions.

```yaml
# .github/actions/setup-tools/action.yml
runs:
  using: composite
  steps:
    - name: Install Trivy
      shell: bash
      run: ...
```

## Pipeline Structure Comparison

### ADO (P4): Single orchestrator file
```
azure-pipelines.yml
  └── imports templates from pipelines/templates/
  └── imports variables from pipelines/variables/
  └── calls scripts from scripts/
```

### GHA (P5): Distributed workflow files
```
.github/workflows/deploy.yml (orchestrator)
  └── calls reusable workflows from .github/workflows/reusable/
  └── uses composite actions from .github/actions/
  └── calls scripts from scripts/
```

**ADO** = monolithic with template imports. **GHA** = distributed with job-level isolation.

## When to Choose Which

### Choose Azure DevOps When:
- Enterprise Azure shop (tight Azure integration)
- Need variable groups + Key Vault secret integration
- Classic release pipelines required (legacy)
- Board/work item integration needed
- Self-hosted agents with VMSS scaling

### Choose GitHub Actions When:
- Open-source projects (free CI/CD for public repos)
- GitHub-native team (code + CI/CD in one place)
- Need rich marketplace ecosystem (18,000+ actions)
- Want OIDC as infrastructure-as-code
- Startup/scale-up environment

### Most EU Companies:
Use **both**. Azure DevOps for enterprise pipelines + boards. GitHub for open-source, personal projects, and increasingly for production CI/CD. Knowing both makes you versatile — this is exactly why P4 + P5 exist as a pair.

## Cost Comparison

| Aspect | Azure DevOps | GitHub Actions |
|---|---|---|
| Free tier | 1 parallel job, 1,800 min/month | 20 concurrent jobs, 2,000 min/month (public) |
| Private repos | 1 free parallel job | 2,000 min/month free |
| Additional parallel jobs | ~$40/month per job | $4/min overage (Linux) |
| Self-hosted | Free (unlimited parallel) | Free (unlimited parallel) |

---

*This comparison is based on building the identical pipeline (build → scan → push → deploy → approve → promote) on both platforms as part of the Atlas Platform Portfolio.*