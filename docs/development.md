# Development and CI

```bash
pre-commit install && pre-commit run --all-files
```

Every pull request runs:

- the same hooks, plus OpenTofu validation, tflint and a Trivy scan of `terraform/`, in the
  [Lint workflow](../.github/workflows/lint.yml), and zizmor in the
  [Security workflow](../.github/workflows/security.yml);
- a link check in the Lint workflow: [lychee](https://lychee.cli.rs/) checks that the relative
  links and `#anchors` in every Markdown file resolve, without fetching external URLs. Run it
  locally with `lychee --offline --include-fragments .`;
- the [Commits workflow](../.github/workflows/commits.yml), which lints every commit against
  [Conventional Commits](https://www.conventionalcommits.org/) and rejects `fixup!` commits;
- the [E2E workflow](../.github/workflows/e2e.yml), which deploys the pinned release on the GitHub
  runner with one kind cluster, podinfo as a Fleet app and the image cache, re-runs expecting no
  changes, and checks that Rancher answers, Rancher AI is installed and keeps saved provider
  settings, podinfo runs on both clusters and the clusters pulled through the cache. On pull
  requests that do not touch `ansible/` it skips the deploy and passes, so Renovate's patch
  automerge waits for the deploy only when it matters;
- the Fleet manifests and Fleet platform check workflows for `fleet/`, and Fleet provider sync
  when the provider values change, described in [fleet/README.md](../fleet/README.md#development).

E2E also runs every Monday on Rancher `head`, pinned to that build's commit tag so both deploys
use the same image; *Actions → E2E → Run workflow* takes another `rancher_image_tag`. The E2E
badge shows the latest run on `main`, which is that Monday run or a manual one; pull requests
deploy the pinned release. No workflow uses cloud resources.

Required checks: `commits / Conventional commits`, `pre-commit`, the `terraform / ...` jobs,
`zizmor`, `e2e`, `validate` and `platform`. Pull requests merge with merge commits only, so each
commit lands on `main` as written. The [Release workflow](../.github/workflows/release.yml) runs
[auto-release](https://github.com/mbologna/auto-release) every Monday at 06:00 UTC and tags a
version when a `feat`, `fix`, `perf`, `revert` or breaking commit landed on `main`. A Renovate
`fix(security)` update, or a manual run, releases at once. Notes are on the
[Releases page](https://github.com/mbologna/rancher-platform/releases).

## Documenting a feature

The README stays a quick start with one row per feature. For a new feature:

1. Add a row to the Features table in the [README](../README.md#features).
2. Add a page `docs/<feature>.md`: what the feature does, a snippet that turns it on, then
   details, caveats and tested-on dates, ending with a **Settings** line that links to its
   section in [configuration.md](configuration.md).
3. Add its variables to [configuration.md](configuration.md) and any new `./manage.sh` command
   to [operations.md](operations.md).

A smaller addition to an existing feature, such as a new Helm chart preset, goes on that
feature's page. Don't add sections to the README.
