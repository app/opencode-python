# Kubernetes

Running the OpenCode server in a cluster with the example manifests in
`k8s/`.

## Prerequisites

- A Kubernetes cluster and `kubectl`.
- A pull secret for GHCR (set `GHCR_USER` and `GHCR_TOKEN` in the shell first):

  ```bash
  kubectl create secret docker-registry ghcr-pull \
    --docker-server=https://ghcr.io \
    --docker-username="$GHCR_USER" \
    --docker-password="$GHCR_TOKEN"
  ```

- A runtime `Secret` based on [k8s/secret.example.yaml](../k8s/secret.example.yaml)
  with real values, applied to the target namespace.

## Deploy

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

The deployment pins the image's built-in user (uid/gid 1000): the image
default is the interactive TUI, so the manifest passes the server command
explicitly in the container `args`. It keeps credentials, the session
database and the uv cache on the `opencode-state` PVC and mounts an `emptyDir`
as the agent working space. It uses `Recreate` because a single writer owns
the state volume.

The image is a multi-arch manifest, so the same deployment works on amd64 and
arm64 nodes; no `nodeSelector` or `--platform` is needed.

The Service exposes port 4096 as `ClusterIP` by default; switch `type` to
`LoadBalancer` for external access.

## Access

```bash
kubectl port-forward svc/opencode 4096:4096
```

Then use the HTTP API as described in [Access](api.md#http-api-agents) with
`http://localhost:4096` and your `OPENCODE_PASSWORD`.

## Notes

- Probes are TCP, because the HTTP API requires Basic auth and probes cannot
  send credentials.
- The `emptyDir` project volume is wiped when the pod restarts. Replace it
  with a `PersistentVolumeClaim` or a projected volume when the project must
  persist.
- Solver runs need memory and CPU: raise the container resources beyond the
  example values for real optimization workloads (see
  [Optimization](optimization.md#resources)).
- Update the `image` field (or pin the `oc-<version>-py<python>` tag instead of
  `latest`) when you move to a new release; see [Updating](updating.md).
- Secrets in the `Secret` are visible to the pod; treat the pod as trusted
  for them, as documented in [Security notes](security.md).
