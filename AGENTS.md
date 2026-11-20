# AGENTS.md

Notes for coding agents working in this repository. [README.md](README.md) covers what it
does and how to use it, and [docs/development.md](docs/development.md) the checks and CI.

## Versioning

SemVer with the pinned Rancher as build metadata: `vX.Y.Z+up<rancher_version>`, e.g.
`v2.2.0+up2.15.3` (pattern A of the
[versioning standard](https://github.com/mbologna/.github/blob/main/VERSIONING.md)).

- Never create, move or delete tags, and never edit a version to cut a release:
  auto-release tags on Mondays from the commit types (`feat` minor; `fix`, `perf`, `revert`
  patch; `!` or a `BREAKING CHANGE:` footer major) and adds the metadata from
  `rancher_version` in `ansible/group_vars/all/config.yml`.
- A change of `rancher_version` releases on its own. A Rancher minor is a breaking change:
  commit it as `feat(deps)!:` (Renovate does), so it bumps the major.
- Keep `rancher_version` and the `# rancher-version:` pin in
  `fleet/platform/turtles-values.yaml` on the same release; the tag records the former.
