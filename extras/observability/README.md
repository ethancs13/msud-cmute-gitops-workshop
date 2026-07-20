# Extras: Observability — Prometheus + Grafana

Add a Prometheus metrics endpoint to your PaperMC server, scrape it with
kube-prometheus-stack, and view a live Grafana dashboard at
`https://grafana.<YOUR_NAME>.mc.labs.cmute.cloud`.

## Prerequisites

A completed Part 1: your PaperMC server running and synced by ArgoCD.

## 1. Add the metrics exporter (the GitOps way)

Three files change in your repo:

- **Dockerfile**: Adds the [Prometheus Exporter](https://github.com/sladkoff/minecraft-prometheus-exporter)
  plugin, exposing metrics at `:9940/metrics` inside the container.
- **k8s/deployment.yaml**: Adds port `9940` and mounts the exporter config.
- **k8s/service.yaml**: Adds a named `metrics` port so Prometheus can scrape it.

Copy the updated files:

```bash
cp extras/observability/Dockerfile Dockerfile
cp extras/observability/deployment.yaml k8s/deployment.yaml
cp extras/observability/service.yaml k8s/service.yaml
cp extras/observability/prometheus-exporter-config.yaml k8s/prometheus-exporter-config.yaml
```

Edit `k8s/kustomization.yaml` and add the new file to `resources`:

```yaml
  - prometheus-exporter-config.yaml
```

Edit `k8s/deployment.yaml` and replace `<YOUR_GITHUB_USERNAME>` with your
GitHub username.

Commit and push:

```bash
git add Dockerfile k8s/
git commit -m "feat: add prometheus metrics exporter"
git push
```

Two things happen:

1. **CI rebuilds your image** with the exporter plugin baked in.
2. **ArgoCD syncs** the updated deployment, service, and configmap.

## 2. Wait for the new image

1. Go to the **Actions** tab in your fork and wait for the build to finish.
2. Force your cluster to pull the new image:

```bash
kubectl rollout restart deployment paper -n paper
```

## 3. Verify the metrics endpoint

Once the new pod is `Running`:

```bash
kubectl port-forward svc/paper -n paper 9940:9940
```

In another terminal:

```bash
curl localhost:9940/metrics
```

You should see metrics like `mc_players_online_total`, `mc_tps` (20 = healthy),
`mc_tick_duration_average`, `mc_loaded_chunks_total`, `mc_entities_total`, and
`mc_jvm_memory`.

## 4. Install kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.label=grafana_dashboard
```

Wait for everything to come up:

```bash
kubectl get pods -n monitoring
```

## 5. Apply the observability resources

Edit these files and replace `<YOUR_NAME>` with your name:

- `extras/observability/certificate.yaml`
- `extras/observability/httproute.yaml`

Then apply:

```bash
kubectl apply -f extras/observability/servicemonitor.yaml
kubectl apply -f extras/observability/dashboard.yaml
kubectl apply -f extras/observability/certificate.yaml
kubectl apply -f extras/observability/httproute.yaml
```

## 6. Add the Grafana listener to your Gateway

Copy the gateway file that includes the third (Grafana) listener:

```bash
cp extras/observability/gateway-patch.yaml k8s/gateway.yaml
```

Edit `k8s/gateway.yaml` and replace `<YOUR_NAME>` in **both** the
`argocd-https` and `grafana-https` hostnames.

Commit and push:

```bash
git add k8s/gateway.yaml
git commit -m "feat: add grafana listener to gateway"
git push
```

ArgoCD syncs the updated Gateway.

## 7. Create the DNS record

Get your Gateway IP:

```bash
kubectl get gateway paper-gateway -n paper
```

```bash
doctl compute domain records create cmute.cloud \
  --record-type A \
  --record-name "grafana.<YOUR_NAME>.mc.labs" \
  --record-data <GATEWAY_EXTERNAL_IP> \
  --record-ttl 300
```

## 8. Log in to Grafana

Get the admin password:

```bash
kubectl get secret -n monitoring prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

Navigate to `https://grafana.<YOUR_NAME>.mc.labs.cmute.cloud`

- **Username:** admin
- **Password:** output from above

The **PaperMC Server** dashboard is under Dashboards — TPS, tick duration,
JVM memory, player count, entities, and more. Hop into your server and watch
the player count go up.