# Development

```bash
pre-commit install && pre-commit run --all-files
```

Every pull request runs the same hooks in the [Lint workflow](../.github/workflows/lint.yml), plus
trivy and zizmor in the [Security workflow](../.github/workflows/security.yml). Pull requests that
touch `ansible/` also run the [E2E workflow](../.github/workflows/e2e.yml): it deploys with one
downstream cluster and podinfo as a Fleet app on the GitHub runner, re-runs expecting no changes,
and checks that Rancher answers, the AI agent/MCP and UI extension are installed, AI provider settings
survive the re-run, and podinfo runs on both clusters.
E2E also runs every Monday on
Rancher `head`, pinned to that build's commit tag so both deploys use the same image; run it by
hand with another tag from *Actions → E2E → Run workflow* (`rancher_image_tag`). No workflow uses
cloud resources.

## Releases

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); the
[Release workflow](../.github/workflows/release.yml) tags a version every Monday at 06:00 UTC when a
`feat`, `fix`, `perf`, `revert` or breaking commit landed on `main` (a Renovate `fix(security)` update
is released at once), and publishes its notes on the [Releases page](https://github.com/mbologna/rancher-platform/releases);
run it by hand to release at once. The Releases page holds every version's notes.

## Documenting a feature

The README stays a quick start; features are documented in `docs/`. For a new feature:

1. Add one row to the Features table in the [README](../README.md#features).
2. Add a page `docs/<feature>.md`: one paragraph on what it does, a snippet that turns it on,
   then details, caveats and tested-on dates, ending with a **Variables** line.
3. Add its variables to [Configuration](reference.md#configuration) and any new `manage.sh`
   command to [Commands](reference.md#commands).

A small extension of an existing feature, such as a new Helm preset, goes on that feature's
page instead. Don't add sections to the README.
