<picture>
  <source media="(prefers-color-scheme: dark)" srcset="pics/tcc_logo_darkmode.png">
  <source media="(prefers-color-scheme: light)" srcset="pics/tcc_logo.png">
  <img alt="The Cybersecurity Center" src="pics/tcc_logo.png">
</picture>

# MSU Denver GitOps Workshop

Deploy a PaperMC Minecraft server to DigitalOcean Kubernetes using GitOps principles.

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?style=for-the-badge&logo=opentofu&logoColor=black)
![DigitalOcean](https://img.shields.io/badge/DigitalOcean-0080FF?style=for-the-badge&logo=digitalocean&logoColor=white)
![Envoy Gateway](https://img.shields.io/badge/Envoy%20Gateway-AC6199?style=for-the-badge&logo=envoyproxy&logoColor=white)
![PaperMC](https://img.shields.io/badge/PaperMC-EEE?style=for-the-badge&logo=minecraft&logoColor=black)

## Prerequisites

- [Git](https://git-scm.com/)
- [Docker](https://docs.docker.com/get-docker/)
- [doctl](https://docs.digitalocean.com/reference/doctl/how-to/install/)
- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- A GitHub account
- A DigitalOcean API token

### Note About Minecraft Version

**Note:** The server runs Minecraft **1.21.11**.

In the Minecraft Launcher, create an installation for version 1.21.11 (Installations → New installation) and use it to connect. The latest client version will not join a 1.21.11 server.

## Lab Environment Setup

### Fork the repository

1. Fork this repository to your GitHub account.

2. GitHub disables workflows on forks by default. Go to the **Actions** tab in your fork and click **"I understand my workflows, enable them"**.

3. The workflow runs two jobs on every push: `secret-scan` and `build`. The `secret-scan` job uses [TruffleHog](https://github.com/trufflesecurity/trufflehog) to scan your git history for leaked credentials (like your DigitalOcean token) and blocks the build if it finds any. Make a small commit to `main` to trigger the workflow, then verify both jobs pass. Once complete, your container image will be available at `ghcr.io/<your-github-username>/msud-cmute-gitops-workshop:latest`.

4. By default, the package GitHub builds is **private** and your cluster will not be able to pull it. Go to your fork's **Packages** → `msud-cmute-gitops-workshop` → **Package settings** → **Change visibility** → **Public**.

### Provision your cluster

1. Install and authenticate doctl:

```bash
doctl auth init --access-token <YOUR_DO_TOKEN>
```

2. Provision your DOKS cluster:

```bash
cd infra/tofu
cp terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` — replace `<YOUR_NAME>` in `cluster_name` with your name (lowercase, no spaces).

4. Apply:

```bash
tofu init
tofu plan
tofu apply
```

Cluster creation takes **~8 minutes**. Grab some water.

5. Save your kubeconfig:

```bash
doctl kubernetes cluster kubeconfig save paper-<YOUR_NAME>
```

Example:

```bash
doctl kubernetes cluster kubeconfig save paper-test
```

6. Verify access:

```bash
kubectl get nodes
```

You should see a single node in `Ready` status.

Example:

```bash
NAME             STATUS   ROLES    AGE   VERSION
default-37gop8   Ready    <none>   14m   v1.36.0
```

### Bootstrap cluster infrastructure

1. Install the Gateway API CRDs and Envoy Gateway:

```bash
kubectl apply --server-side --force-conflicts \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/experimental-install.yaml
```

You should see:

```bash
customresourcedefinition.apiextensions.k8s.io/backendtlspolicies.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/grpcroutes.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/listenersets.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/referencegrants.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/tcproutes.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/tlsroutes.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/udproutes.gateway.networking.k8s.io serverside-applied
validatingadmissionpolicy.admissionregistration.k8s.io/safe-upgrades.gateway.networking.k8s.io serverside-applied
validatingadmissionpolicybinding.admissionregistration.k8s.io/safe-upgrades.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/xbackendtrafficpolicies.gateway.networking.x-k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/xmeshes.gateway.networking.x-k8s.io serverside-applied
```

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.8.2 \
  -n envoy-gateway-system \
  --create-namespace \
  --skip-crds
```

```bash
kubectl apply -f infra/envoy-gateway/gatewayclass.yaml
```

Verify Envoy Gateway is running and the GatewayClass is accepted:

```bash
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass eg
```

```bash
NAME   CONTROLLER                                      ACCEPTED   AGE
eg     gateway.envoyproxy.io/gatewayclass-controller   True       14s
```

2. Install cert-manager:

```bash
kubectl apply --server-side -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.0/cert-manager.yaml
```

```bash
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=120s
```

3. Create the DigitalOcean DNS-01 secret and ClusterIssuer (use the same DO token from earlier):

NOTE: BE SURE TO REPLACE THE EMAIL LINE!!!

```bash
kubectl create secret generic digitalocean-dns \
  --namespace cert-manager \
  --from-literal=access-token=<YOUR_DO_TOKEN>
```

Edit `infra/cert-manager/clusterissuer.yaml` and replace `<YOUR_EMAIL>` with your email. Then run:

```bash
kubectl apply -f infra/cert-manager/clusterissuer.yaml
```

4. Install ArgoCD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

5. Verify ArgoCD is running:

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

### Prepare ArgoCD for the shared Gateway

The single `paper-gateway` (defined in `k8s/gateway.yaml`) has two listeners: a TCP listener for Minecraft and an HTTPS listener for the ArgoCD UI. They share the same LoadBalancer IP.

1. Tell ArgoCD not to terminate TLS itself (the Gateway does it):

```bash
kubectl patch deployment argocd-server -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'
kubectl rollout status deployment/argocd-server -n argocd
```

2. Edit `k8s/argocd-httproute.yaml` and replace `<YOUR_NAME>` with your name, then apply:

```bash
kubectl apply -f k8s/argocd-httproute.yaml
```

### Deploy with ArgoCD

1. Look at all files in `k8s/`:
   - `namespace.yaml`
   - `configmap.yaml`
   - `persistentvolumeclaim.yaml`
   - `deployment.yaml` IMPORTANT: replace `<YOUR_GITHUB_USERNAME>` with your GitHub username (must be lowercase)
   - `service.yaml`
   - `gateway.yaml` IMPORTANT: replace `<YOUR_NAME>` in the ArgoCD HTTPS listener hostname
   - `tcproute.yaml`
   - `certificate.yaml` IMPORTANT: replace `<YOUR_NAME>` in both certs (matches your DNS records below)

2. In `argocd/application.yaml`, look at the file and replace `<YOUR_GITHUB_USERNAME>` with your GitHub username.

3. Check that you didn't miss any placeholders:

```bash
grep -rn "YOUR_NAME\|YOUR_GITHUB" k8s/ argocd/ && echo "^^ FIX THESE BEFORE CONTINUING" || echo "all placeholders replaced"
```

4. Commit and push:

```bash
git add -A
git commit -m "chore: configure k8s manifests with my values"
git push
```

5. Apply the ArgoCD application:

```bash
kubectl apply -f argocd/application.yaml
```

6. Watch ArgoCD deploy everything:

```bash
kubectl get applications -n argocd
kubectl get pods -n paper
```

The paper pod takes **1–2 minutes** to become `1/1 Ready` (the startup probe waits for the Minecraft server to boot).

### Expose the server

All traffic (Minecraft and the ArgoCD UI) flows through the single Gateway LoadBalancer.

1. Get your Gateway's external IP:

```bash
kubectl get gateway paper-gateway -n paper
```

The `ADDRESS` field takes **1–3 minutes** to appear while DigitalOcean provisions the load balancer. Your certificates take another 1–3 minutes to become Ready — check with:

```bash
kubectl get certificates -n paper
```

2. (Optional) Verify the Minecraft port is reachable through the Gateway:

```bash
timeout 3 bash -c '</dev/tcp/<GATEWAY_EXTERNAL_IP>/25565' && echo OPEN || echo CLOSED
```

If this prints `OPEN`, Envoy is routing TCP traffic to your server. If it prints `CLOSED`, wait a minute and try again before debugging.

3. Create a DNS record for ArgoCD pointing to the Gateway IP:

```bash
doctl compute domain records create cmute.cloud \
  --record-type A \
  --record-name "argocd.<YOUR_NAME>.mc.labs" \
  --record-data <GATEWAY_EXTERNAL_IP> \
  --record-ttl 300
```

4. Create a DNS record for your Minecraft server pointing to the **same** Gateway IP:

```bash
doctl compute domain records create cmute.cloud \
  --record-type A \
  --record-name "<YOUR_NAME>.mc.labs" \
  --record-data <GATEWAY_EXTERNAL_IP> \
  --record-ttl 300
```

5. Get the initial ArgoCD admin password and log in at `https://argocd.<YOUR_NAME>.mc.labs.cmute.cloud`:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

6. Connect with your Minecraft client (version **1.21.11**) to `<YOUR_NAME>.mc.labs.cmute.cloud`.

### Test GitOps

Make a change and watch ArgoCD sync it automatically.

1. Edit `k8s/configmap.yaml`. Change `max-players` to `50`.

2. Edit `k8s/deployment.yaml`. Change the `configmap-hash` annotation to any new value (ex: `"2"`). This triggers a pod restart so Minecraft picks up the new config.

3. Commit and push.

4. Watch the sync:

```bash
kubectl get pods -n paper
```

Within about 3 minutes, ArgoCD will detect the change and roll out a new pod automatically. You'll briefly be disconnected from the server while the pod restarts — that's the deployment happening. Watch it live in the ArgoCD UI.

## Extras

Add Prometheus metrics and a Grafana dashboard for your server: [extras/observability](extras/observability/README.md)

## Cleanup

Cluster teardown is handled by the instructor after the workshop. Leave your cluster running.