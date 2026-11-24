# Fleet cluster templates

Fleet bundles that create Kubernetes clusters from a Rancher management cluster with Cluster API
(CAPI). This directory holds ClusterClasses, a shared AWS identity and three example clusters.
Rancher Turtles imports each cluster into Rancher once it is ready.

The rest of this repository ([README](../README.md)) deploys the management cluster and installs
the CAPI providers with the values in [`platform/`](platform/). Until 2026-11-19 this directory
was the separate rancher-fleet-clusters repository, now archived with its history.

| Example | Class | Infrastructure | Nodes |
|---|---|---|---|
| [`docker-rke2-example`](clusters/docker-rke2-example/cluster.yaml) | `docker-rke2-v136` | Docker containers on the management host (development only) | 1 control plane, 1 worker |
| [`aws-rke2-example`](clusters/aws-rke2-example/cluster.yaml) | `aws-rke2-v136` | EC2 with an internal NLB | 1 control plane, 2 workers |
| [`aws-eks-example`](clusters/aws-eks-example/cluster.yaml) | none | EKS with a managed node group | managed |

Registering the GitRepo applies every example. Once their `REPLACE_WITH_*` values are filled
in, the AWS examples create billable EC2 instances, load balancers, EKS control planes and
storage. Delete the examples you do not want from your fork first.

## Versions

| Component | Pinned in | Set by |
|---|---|---|
| Rancher, on management Kubernetes v1.34–v1.36 | [`turtles-values.yaml`](platform/turtles-values.yaml) `rancher-version` | `rancher_version` in [`config.yml`](../ansible/group_vars/all/config.yml), which Renovate updates |
| Rancher Turtles | [`turtles-values.yaml`](platform/turtles-values.yaml) `chart-version` | the Rancher release |
| CAPI core | [`turtles-values.yaml`](platform/turtles-values.yaml) | the Turtles catalogue |
| Docker (CAPD), AWS (CAPA) and RKE2 (CAPRKE2) providers | [`providers-values.yaml`](platform/providers-values.yaml) | the Turtles catalogue |
| Workload RKE2 v1.36.6+rke2r1 | the cluster manifests | Renovate, patches |
| AWS cloud controller manager v1.36.1 | [`aws-ccm-v136.yaml`](clusterclasses/aws-rke2/aws-ccm-v136.yaml) | Renovate, patches automerge |
| Docker node image kindest/node:v1.36.4 | [`docker-rke2-example`](clusters/docker-rke2-example/cluster.yaml) | Renovate, patches |

Rancher is the only provider stack version chosen by hand or by Renovate, and it has one pin:
`rancher_version` in the Ansible [`config.yml`](../ansible/group_vars/all/config.yml), the
release that `deploy` installs and that release tags record. Each Rancher release bundles one
Turtles release (`turtlesVersion` in its `build.yaml`), and each Turtles release has a
[provider catalogue][catalog] naming the core CAPI and provider releases it is tested with.
[`scripts/sync-providers.py`](scripts/sync-providers.py) reads `rancher_version`, fetches both
files at their release tags and rewrites the `rancher-version`, Turtles and provider pins in
`platform/` to match:

```bash
python3 scripts/sync-providers.py          # rewrite the pins
python3 scripts/sync-providers.py --check  # report drift, change nothing
```

Set `GITHUB_TOKEN` to read GitHub with your rate limit instead of the anonymous one. CAPI
resources use the `v1beta2` API.

Live-tested on 17 October 2026: the Docker and AWS RKE2 examples reached `Available` and were
imported into Rancher. The EKS example has not been live-tested.

## Quick start

1. **Deploy the management cluster** with this repository's Ansible and the providers enabled. Add
   `capa_aws_access_key_id` and `capa_aws_secret_access_key` to its `secrets.yml` to get the
   AWS provider; without them only the Docker and RKE2 providers are installed.

   ```bash
   ./manage.sh deploy -e capi_providers_enabled=true
   ```

2. **Fork this repository and configure the examples** under `fleet/`. Replace every `REPLACE_WITH_*` value
   (see [AWS](#aws)) or delete the examples you do not need. Commit and push: Fleet reads the
   remote branch, not local files.

3. **Validate** the manifests and the management cluster, from `fleet/`. Both checks are read-only.

   ```bash
   python3 scripts/validate-repo.py --schemas --deployment-check
   python3 scripts/check-platform.py --context <management-context>
   ```

   The first fails while placeholders remain. The second checks provider versions and
   ownership, controller availability, feature flags, CRDs, Rancher's `server-url`, and that
   no example cluster name already exists. It does not test AWS permissions or networking.
   Add `--without aws` when the deploy had no AWS credentials, and `--without docker` when it
   ran without CAPD.

4. **Register the GitRepo.** Point `spec.repo` and `spec.branch` in
   [`gitrepo.yaml`](gitrepo.yaml) at your fork (its paths are already under `fleet/`), then
   apply it:

   ```bash
   kubectl --context <management-context> apply -f gitrepo.yaml
   kubectl --context <management-context> get bundles -n fleet-local
   kubectl --context <management-context> get clusters -A
   ```

   The Ansible deploy can do this step instead: add `fleet_apps_capi_templates` to
   `fleet_apps` (see [Cluster API](../docs/cluster-api.md)), pointing its
   `repo` at your fork.

Fleet applies the identity, the ClusterClasses and then the clusters, in dependency order.
The dependency names include the GitRepo name, `capi-cluster-templates`; rename both together.
`keepResources: true` keeps CAPI clusters when the GitRepo is deleted or its paths change.

An installation that already runs these clusters or older provider versions needs the staged
upgrade in [docs/migration.md](docs/migration.md), not a fresh install.

## AWS

Create CAPA's IAM roles once per account, with a `clusterawsadm` release matching CAPA:

```bash
clusterawsadm bootstrap iam create-cloudformation-stack
```

CAPA reads two Secrets in `capa-system`. The Ansible deploy creates both from `secrets.yml`.

| Secret | Keys | Used by |
|---|---|---|
| `capa-credentials` | `AWS_B64ENCODED_CREDENTIALS`: a base64 AWS shared-credentials file | CAPA controller |
| `cluster-identity` | `AccessKeyID`, `SecretAccessKey` | `AWSClusterStaticIdentity` `cluster-identity`, usable from the `default` namespace |

**Network.** The RKE2 class puts the Kubernetes API behind an internal NLB, so the
management cluster needs a route into the workload VPC. The simplest layout reuses the
management host's VPC: set `vpcID`, a public `subnetID`, `publicIP: true`, and the VPC CIDR in
both `nodeCIDRs` and `apiServerAllowedCIDRs`. Otherwise connect the VPCs by peering or VPN.
A CAPA-created VPC uses `10.0.0.0/16`, which must not overlap the management, pod or service
networks. Nodes need outbound internet access to download RKE2 and images.

**EKS** needs a VPC and at least two subnets in different availability zones, and a
Kubernetes version that EKS currently offers in the region.

## Cluster classes

Published templates are immutable; a change needs a new class name. The `-v136` classes are
for new clusters. The original `aws-rke2` and `docker-rke2` classes stay for clusters that
already use them.

AWS RKE2 (`aws-rke2-v136`) variables:

| Variable | Default | Meaning |
|---|---|---|
| `region` | `eu-west-1` | AWS region |
| `amiID` | required | Base OS AMI; CAPRKE2 installs RKE2 at boot |
| `sshKeyName` | empty | EC2 key pair |
| `controlPlaneMachineType`, `workerMachineType` | `t3.large` | Instance types |
| `cni` | `calico` | RKE2 CNI |
| `awsClusterIdentityName` | `cluster-identity` | AWS identity |
| `vpcID`, `subnetID` | empty | Existing network; set both or neither |
| `publicIP` | `false` | Public node addresses |
| `apiServerAllowedCIDRs` | required | Clients allowed to reach the API load balancer |
| `nodeCIDRs` | required | Private node addresses |

Nodes take their hostnames from IMDSv2 and run the AWS cloud controller manager, which a
ClusterResourceSet installs on clusters labelled `ccm: aws-v136` and `ccm-version: "1.36"`. The
legacy `ccm: aws` label selects the old apply-once payload.

Docker RKE2 (`docker-rke2-v136`) takes one variable, `dockerImage`, the `kindest/node` image.
CAPD needs a Docker network called `kind` that pods can reach; the Ansible deploy creates it.

The EKS example uses `AWSManagedControlPlane` and `AWSManagedMachinePool` directly. Its
Kubernetes version is independent of the RKE2 examples.

## Providers without this repository's Ansible

Merge these files into the management cluster's existing Turtles releases. Do not install a
second `rancher-turtles` release.

| File | Purpose |
|---|---|
| [`platform/turtles-values.yaml`](platform/turtles-values.yaml) | `rancher-turtles` chart: core CAPI version and config Secret |
| [`platform/providers-values.yaml`](platform/providers-values.yaml) | `rancher-turtles-providers` chart: CAPA, CAPD and both CAPRKE2 providers |
| [`platform/core-config.yaml`](platform/core-config.yaml) | Secret enabling core CAPI's `ClusterTopology` feature |

Use the charts from the Turtles tag in `turtles-values.yaml` or the matching Rancher-packaged
chart. Apply `core-config.yaml` in `cattle-capi-system` before the core provider reconciles.
CAPA needs its Secrets before it starts. The values keep RKE2 and CAPD in
`cattle-turtles-system` to match migrated installs; the Ansible deploy uses the chart's own
namespaces instead because Helm cannot adopt an existing namespace. `check-platform.py`
accepts both.

## Repository layout

```text
clusterclasses/   ClusterClasses and the AWS CCM ClusterResourceSets (Fleet bundles)
identities/       AWS cluster identity (Fleet bundle)
clusters/         example clusters (Fleet bundles)
platform/         provider chart values; applied by the platform, never by Fleet
scripts/          validate-repo.py, check-platform.py, sync-providers.py and schema helpers
tests/            unit tests for the scripts
docs/             migration guide
gitrepo.yaml      Fleet GitRepo for the three bundle directories
```

## Development

Requirements: [uv][uv], [yq][yq] v4.44.3 or newer and Helm v4 (CI renders the charts with the
versions in `.github/workflows/fleet-validate.yaml`). uv installs the Python and the packages
that `uv.lock` pins.

```bash
uv run --group fleet python scripts/validate-repo.py --schemas
uv run --group fleet python -m unittest discover -s tests
```

`validate-repo.py` checks YAML, Fleet dependencies, template references, patch paths, CIDRs
and version conventions. `--schemas` downloads the pinned CRDs, Kubernetes schemas and Turtles
charts, then validates every resource and renders both platform charts offline, which also
checks the values files against the charts' schemas. Static checks
do not cover CEL rules, admission defaults or a real bootstrap.

GitHub Actions runs three workflows:

- **Fleet manifests** checks the provider pins against the Turtles catalogue, then runs the
  schema validation and unit tests on every pull request and every push to `main`.
- **Fleet platform check** builds a disposable management cluster on the runner with this
  repository's Ansible, installs this branch's `providers-values.yaml` and runs
  `check-platform.py`. It then registers `gitrepo.yaml`, pointed at the commit under test and
  narrowed to the Docker class and example, waits for CAPI to provision
  `docker-rke2-example`, for Turtles to import it into Rancher and for a pod to run on it,
  and deletes the cluster. It deploys the Ansible `rancher_version`, which the `platform/` pins
  follow.
  Its `platform` job is a required check: it runs when a pull request changes `platform/`,
  the Docker class or example, `gitrepo.yaml`, the check, the `capi_providers` role or the
  workflow, and is skipped
  (which passes) otherwise. CAPA gets dummy credentials, so it creates no AWS resources.
  The weekly run also fails if the pins drift from the Turtles catalogue.
- **Fleet provider sync** runs `sync-providers.py` on every pull request from this repository
  that changes `platform/*-values.yaml` or the Ansible `config.yml`, and commits any rewritten pins to the branch as
  `github-actions[bot]`. GitHub holds the workflow runs that this `GITHUB_TOKEN` push starts
  until someone with write access approves them; the job approves them, so the required checks
  run on the synced commit. The checks on the replaced commit fail on the drift. Pull requests
  from forks get no sync commit: run the script and push.

Renovate uses the shared [mbologna/.github preset][preset], so routine updates automerge on
green CI after its release-age gate. Renovate updates `rancher_version` only: Turtles, core
CAPI, CAPD, CAPA and CAPRKE2 are disabled there, and Provider sync adds them and the
`rancher-version` pin to the Rancher update PR. A Rancher patch automerges once the required
`e2e` and `platform` checks have deployed the stack and provisioned the Docker example; Rancher
minors and majors wait for a person. The preset lists `github-actions[bot]` in
`gitIgnoredAuthors`, so the sync commit does not stop Renovate from rebasing the branch.
RKE2 and kind node image patches are grouped and automerge on the same `platform` check, which
provisions the Docker example on them. AWS CCM patches automerge on the `validate` check, which
only confirms that registry.k8s.io serves the pinned image: nothing exercises AWS. RKE2 minor upgrades are disabled because they need new classes and a CCM
migration.

[preset]: https://github.com/mbologna/.github/blob/main/renovate-config.json
[catalog]: https://github.com/rancher/turtles/blob/main/internal/controllers/clusterctl/config-prime.yaml
[uv]: https://docs.astral.sh/uv/
[yq]: https://github.com/mikefarah/yq
