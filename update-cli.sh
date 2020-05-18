#!/usr/bin/env bash
# Update various CLI

# Update `eksctl`
echo "Updating 'eksctl'..."
EKS_VERSION=$(eksctl version | cut -d',' -f3 | cut -d':' -f2 | tr -d } | tr -d \")
echo "Current 'eksctl' version: ${EKS_VERSION}"
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
EKS_VERSION=$(eksctl version | cut -d',' -f3 | cut -d':' -f2 | tr -d } | tr -d \")
echo "New 'eksctl' version: ${EKS_VERSION}"
unset EKS_VERSION

# Update `kubectl`
echo "Updating 'kubectl'..."
KUBE_VERSION=$(kubectl version --short --client | cut -d':' -f2)
echo "Current 'kubectl' version: ${KUBE_VERSION}"
curl --silent --location https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl --output /tmp/kubectl
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/kubectl
KUBE_VERSION=$(kubectl version --short --client | cut -d':' -f2)
echo "New 'kubectl' version: ${KUBE_VERSION}"
unset KUBE_VERSION

# Update AWS CLI
AWS_CLI_VERSION=$(aws --version | cut -d '/' -f2 | cut -d' ' -f1)
echo "Current 'aws' version: ${AWS_CLI_VERSION}"
curl --silent --location "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" --output "/tmp/awscliv2.zip"
unzip -qo /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update
AWS_CLI_VERSION=$(aws --version | cut -d '/' -f2 | cut -d' ' -f1)
echo "New 'aws' version: ${AWS_CLI_VERSION}"
unset AWS_CLI_VERSION

