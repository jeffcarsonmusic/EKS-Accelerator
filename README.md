# EKS-accelerator
This solution deploys EKS with eksctl and karpenter instead of cluster auto scaler

# Overview
**ci/docker** - Spins a local docker container with all dependecies to deploy the solution\
**infrastructure** - Contains infrastructure manifests and all things infra\
**scripts** - Contains any non-infrastructure scripts\
**create.sh** - Start here to launch the stack\
**destroy.sh** - Use this to tear down the stack (Work in progress)

# EBS Volumes
 - This solution uses the aws-ebs-csi-driver to enable gp3 EBS volumes with karpenter https://github.com/kubernetes-sigs/aws-ebs-csi-driver
 - This solution uses cloudformation to launch a custom launch template since it's currently the only way to have encrypted EBS with karpenter. When the karpenter project updates the karpenter spec to enable EBS encryption this approach can change. 
https://karpenter.sh/v0.7.1/aws/launch-templates/

# Command quick reference
Karpenter logs

kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter


# Links
Karpenter - https://karpenter.sh/ \
EKS - https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html \
eksctl - https://eksctl.io
