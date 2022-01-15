#!/bin/sh

KUBECONFIG=/etc/kubernetes/kubelet.kubeconfig
HOSTNAME=$(cat /etc/hostname)

function pause_exit() {
  echo "Sleeping"
  sleep 10000d
  exit 0
}

function check_label() {
  # Check for gvisor.enabled node label, stop if it exists
  NODE_LABEL=$(kubectl --kubeconfig=$KUBECONFIG get nodes -l gvisor.enabled -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' |grep $HOSTNAME)

  if [ -z "$NODE_LABEL" ]; then
    echo "Missing gvisor.enabled label for $HOSTNAME"
  else
    echo "gvisor.enabled label exists for $HOSTNAME"
    pause_exit
  fi
}

function check_runtime() {
  # Check for gvisor runtime, update node label, uncordon the node
  # This should only run after the first reboot since check_label will sleep the pod
  # for the rest of the daemonSet's existence
  if [ -e /usr/local/bin/runsc ]; then
    kubectl --kubeconfig=$KUBECONFIG label node "$HOSTNAME" gvisor.enabled=true
    kubectl uncordon "$HOSTNAME"
    pause_exit
  else
      echo "No gvisor runsc runtime installed"
      echo "Draining node"
      kubectl --kubeconfig=$KUBECONFIG drain "$HOSTNAME" --force --ignore-daemonsets
      install_runtime
      # Reboot node since systemctl isn't available
      reboot
  fi
}

function install_runtime() {
  set -euo pipefail
  echo "Attempting to install gvisor runtime"

  (
    set -e
    ARCH=$(uname -m)
    URL=https://storage.googleapis.com/gvisor/releases/release/latest/${ARCH}
    wget ${URL}/runsc ${URL}/runsc.sha512 \
      ${URL}/containerd-shim-runsc-v1 ${URL}/containerd-shim-runsc-v1.sha512
    sha512sum -c runsc.sha512 \
      -c containerd-shim-runsc-v1.sha512
    rm -f *.sha512
    chmod a+rx runsc containerd-shim-runsc-v1
    sudo mv runsc containerd-shim-runsc-v1 /usr/local/bin
  )

  # Configure gvisor runtime
  cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins."io.containerd.runtime.v1.linux"]
  shim_debug = true
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF

}

# If we're running in daemonset pod, copy the script to the host
# Then chroot into the host and run this script
#
# Otherwise, we're on the host so check the node's labels
# Then install gvisor on the node
if [ -e /install-gvisor.sh ]; then
  cp /install-gvisor.sh /host/tmp/install-gvisor.sh
  chroot /host /bin/bash /tmp/install-gvisor.sh
  pause_exit
else
  check_label
  check_runtime
fi
