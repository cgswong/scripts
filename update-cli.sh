#!/usr/bin/env bash
# Update various CLI
# Version: 1.0.0

# Update `eksctl`
echo "Updating 'eksctl'..."
if command -v eksctl &>/dev/null; then
  EKS_VERSION=$(eksctl version | cut -d',' -f3 | cut -d':' -f2 | tr -d } | tr -d \")
  echo "Current 'eksctl' version: ${EKS_VERSION}"
fi
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
EKS_VERSION=$(eksctl version | cut -d',' -f3 | cut -d':' -f2 | tr -d } | tr -d \")
echo "New 'eksctl' version: ${EKS_VERSION}"
unset EKS_VERSION

# Update `kubectl`
echo "Updating 'kubectl'..."
if command -v kubectl &>/dev/null; then
  KUBE_VERSION=$(kubectl version --short --client | cut -d':' -f2)
  echo "Current 'kubectl' version: ${KUBE_VERSION}"
fi
if [[ $(uname -s) == "Darwin" ]]; then
  curl --silent --location "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl" --output /tmp/kubectl
else
  curl --silent --location "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" --output /tmp/kubectl
fi
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/kubectl
KUBE_VERSION=$(kubectl version --short --client | cut -d':' -f2)
echo "New 'kubectl' version: ${KUBE_VERSION}"
unset KUBE_VERSION

# Update AWS CLI
if command -v aws &>/dev/null; then
  AWS_CLI_VERSION=$(aws --version | cut -d '/' -f2 | cut -d' ' -f1)
  echo "Current 'aws' version: ${AWS_CLI_VERSION}"
fi
if [[ $(uname -s) == "Darwin" ]]; then
  curl --silent --location "https://awscli.amazonaws.com/AWSCLIV2.pkg" --output "/tmp/AWSCLIV2.pkg"
  sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
else
  curl --silent --location "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" --output "/tmp/awscliv2.zip"
  unzip -qo /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install --update
fi
AWS_CLI_VERSION=$(aws --version | cut -d '/' -f2 | cut -d' ' -f1)
echo "New 'aws' version: ${AWS_CLI_VERSION}"
unset AWS_CLI_VERSION

# Update aws-session-manager-plugin
echo "Installing 'aws-sessionmanager-plugin'"
if [[ $(uname -s) == "Darwin" ]]; then
  curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "/tmp/sessionmanager-bundle.zip"
  unzip -q /tmp/sessionmanager-bundle.zip -d /tmp
  sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
  rm -rf /tmp/sessionmanager-bundle /tmp/sessionmanager-bundle.zip
else
  curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
  sudo yum install -y session-manager-plugin.rpm
fi
echo "Completed 'aws-sessionmanager-plugin' installation"

# Update istioctl
if command -v istioctl &>/dev/null; then
  ISTIOCLI_VERSION=$(istioctl version --short --remote=false)
  echo "Current 'istioctl' version: ${ISTIOCLI_VERSION}"
fi
cd ${HOME}
curl -sL https://istio.io/downloadIstio | sh -
ISTIOCLI_NEW_VERSION=$(ls -td ${HOME}/istio-* | head -1 | cut -d'-' -f2)
sudo ln -sf ${HOME}/istio-${ISTIOCLI_NEW_VERSION}/bin/istioctl /usr/local/bin/istioctl
ISTIOCLI_VERSION=$(istioctl version --short --remote=false)
echo "New 'istioctl' version: ${ISTIOCLI_VERSION}"
cd -
unset ISTIOCLI_NEW_VERSION
unset ISTIOCLI_VERSION
