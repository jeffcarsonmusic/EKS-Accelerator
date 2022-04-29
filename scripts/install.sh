#!/bin/bash
set -e

# Set Environment variables
export EKS_DIR="infrastructure/eks-cluster"
export KARP_LAUNCH_TEMPLATE="infrastructure/karpenter-launch-template"
export PROV_DIR="infrastructure/karpenter-provisioner"
export SCRIPTS_DIR="scripts"

source ${SCRIPTS_DIR}/user.env
rm -rf ${SCRIPTS_DIR}/user.env


##=================================================================================================###
### Create EKS cluster - creates a new EKS cluster via eksctl. 
###=================================================================================================###

echo " "
echo "********Launching EKS cluster***********"

# Ensure ec2 spot service linked role is created for karpenter auto-provisioning/scaling to work
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com 2> /dev/null || true

# Configure/render the eks cluster template
helm template eks-cluster ${EKS_DIR} \
    --set awsRegion=${AWS_REGION} \
    --set clusterName=${CLUSTER_NAME} \
    > ${SCRIPTS_DIR}/generated-cluster-template.yaml

# Create the eks cluster if cluster doesn't exist
if ! eksctl get cluster --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null 2>&1 ; then
    eksctl create cluster -f ${SCRIPTS_DIR}/generated-cluster-template.yaml
fi

echo " "
echo "********Waiting for the EKS cluster to be healthy***********"
# Wait until cluster and nodegroup(s) are seen as active and ready
aws eks wait cluster-active --region=${AWS_REGION} --name ${CLUSTER_NAME} 

echo " "
echo "********Patching Storage Class***********"
# Update default storage class to encrypted storage class (standard unencrypted gp2 is aws eks default)
kubectl apply -f ${EKS_DIR}/storageclass.yaml
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo " "
echo "********Waiting for the EKS node group to be healthy***********"
eks_nodegroups=($(eksctl get nodegroup --region "${AWS_REGION}" --cluster "${CLUSTER_NAME}" -o json | jq -c -r '.[].Name | @sh' | tr -d \'\"))
for ng in "${eks_nodegroups[@]}"
do
    echo "Waiting for Ready status of Node Group: ${ng}..."
    aws eks wait nodegroup-active --region=${AWS_REGION} --cluster-name ${CLUSTER_NAME} --nodegroup-name ${ng}
done 

# Update kubeconfig
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

###=================================================================================================###
### Configure AWS karpenter Resources (cluster is create at this point)
###=================================================================================================###

echo " "
echo "********Deploy Karpenter Launch Template Cloudformation***********"
# render launch template cloudformation for karpenter. this can be deprecated once Karpenter allows for declaring encrypted EBS in the provisioner spec below.
helm template karpenter-launch-template ${KARP_LAUNCH_TEMPLATE} \
    --set awsRegion=${AWS_REGION} \
    --set clusterName=${CLUSTER_NAME} \
    > ${SCRIPTS_DIR}/generated-karp-launch-template.yaml

# launch rendered cloudformation for karpenter launch template 
aws cloudformation create-stack \
  --stack-name KarpenterLaunchTemplateStack \
  --template-body file://${SCRIPTS_DIR}/generated-karp-launch-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM --query StackId \
  --region ${AWS_REGION}

# wait for stack to launch
aws cloudformation wait stack-create-complete \
    --stack-name KarpenterLaunchTemplateStack \
    --region ${AWS_REGION}

echo " "
echo "********Create Karpenter provisioner***********"
# Create Karpenter provisioner. Karpenter is installed in the cluster configuration and should be ready for a provisioner at this point. Provisioner documentation and configuration options are at https://karpenter.sh/v0.6.2/provisioner/

# Configure/render the karpenter provisioner template
helm template karpenter-provisioner ${PROV_DIR} \
    --set clusterName=${CLUSTER_NAME} \
    > ${SCRIPTS_DIR}/generated-provisioner-template.yaml

kubectl apply -f ${SCRIPTS_DIR}/generated-provisioner-template.yaml

echo "Done"

# sample container deployments in 3 namespaces. Uncomment to deploy, or run from the command line after the stack is built.

#kubectl create ns inflate1ns
#kubectl create ns inflate2ns

# Sample deployments for testing
#kubectl create deployment inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.2 
#kubectl scale deployment inflate --replicas 200

#kubectl create deployment inflate1 --image=public.ecr.aws/eks-distro/kubernetes/pause:3.2 -n inflate1ns
#kubectl scale deployment inflate1 -n inflate1ns --replicas 200

#kubectl create deployment inflate2 --image=public.ecr.aws/eks-distro/kubernetes/pause:3.2 -n inflate2ns
#kubectl scale deployment inflate2 -n inflate2ns --replicas 200





