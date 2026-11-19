# Rancher AI

Each host's Rancher management cluster gets [Liz, the Rancher AI Assistant](https://documentation.suse.com/cloudnative/rancher-ai/1.1.0/en/quick-start.html):
the agent and MCP in `cattle-ai-agent-system`, and the UI extension in `cattle-ui-plugin-system`.
Reload the Rancher UI after installation, then configure a provider and model under
**Global Settings → AI Assistant**. No Ollama server, model or provider credentials are installed.
Later deploys preserve provider settings and credentials saved through the UI.

AI 1.1.0's agent chart declares Rancher 2.13 and Kubernetes <1.35 in its
[catalogue annotations](https://github.com/rancher/rancher-ai-agent/blob/v1.1.0/chart/agent/Chart.yaml),
although the quick start says Rancher 2.13 or above. This project installs it directly with Helm on
the pinned Rancher 2.15/Kubernetes 1.36 platform. Agent/MCP readiness and UI extension loading were
verified on that platform; LLM requests have not been tested.
The [UI extension](https://github.com/rancher/ui-plugin-charts/blob/main/charts/rancher-ai-ui/1.1.0/Chart.yaml)
is marked Prime-only. Set `rancher_ai_enabled: false` to skip managing AI; this leaves an existing
installation in place.

`./manage.sh uninstall-rancher` removes Rancher AI along with Rancher.

**Variables:** `rancher_ai_enabled` (see [Configuration](reference.md#configuration)).
