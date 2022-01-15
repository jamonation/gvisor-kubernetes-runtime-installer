# Install [gVisor](https://gvisor.dev) as a containerd Kubernetes Runtime

## Overview
This project installs gVisor as a containerd runtime on Kubernetes worker nodes. It is intended to be used in managed Kubernetes environments, where direct access to the underlying control plane and worker nodes is unavailable or is difficult to configure.

The install process uses a `daemonset` to run installer pods on each node. **Note that every node will need to reboot to enable the runtime.**

Each pod uses a `hostPath` volume that exposes the worker node's `/` filesystem to the running container.

The container then checks the host for the `runsc` binary, and if it does not exist, uses `chroot` to run the install script, which downloads and configures gVisor as a containerd runtime on the node.

Once `runsc` is installed, the pod reboots the node and then sets a `gvisor.enabled: true` label on the node. This label can be used to identify nodes that have gVisor installed and to further schedule pods that should use the `runsc` runtime.

## Using this repository

To install gVisor to your worker nodes using this repository, you will need a recent version of `kubectl` and access to your cluster as a user with the `cluster-admin` role.

Deploy the `daemonset` using Kustomize:

```command
kubectl apply -k ./base
```

Examine the `kube-system` namespace for the `gvisor-installer` pods:

```command
kubectl -n kube-system get pods -l name=gvisor-installer
```

You should receive output like this:

```
NAME                     READY   STATUS    RESTARTS   AGE
gvisor-installer-4q7ck   1/1     Running   0          38m
gvisor-installer-dgvhp   1/1     Running   0          38m
gvisor-installer-l6rg5   1/1     Running   0          38m
```

Once your nodes have all rebooted, check that gVisor is enabled on each based on the `gvisor.enabled` node label:

```command
kubectl get nodes -l gvisor.enabled=true
```

You should receive output like the following:

```
NAME                   STATUS   ROLES    AGE     VERSION
pool-bel8x49it-ul1gf   Ready    <none>   2d21h   v1.21.5
pool-bel8x49it-ul1gm   Ready    <none>   2d21h   v1.21.5
pool-bel8x49it-ul1gq   Ready    <none>   2d21h   v1.21.5
```

## Notes
While this technique is only tested with gVisor, it should be relatively generic and work with other runtimes like [sysbox](https://github.com/nestybox/sysbox) or [kata-containers](https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/containerd-kata.md).

## Future
This repository uses Kustomize to manage Kubernetes manifests. Currently there is a single `base` directory that contains the `daemonset` resource manifest. A future version of this project will use overlays to enable things like choosing to set gVisor (or another runtime) as the default `plugins.cri.containerd.default_runtime`, or to enable multiple runtimes. Pull requests are welcome!
