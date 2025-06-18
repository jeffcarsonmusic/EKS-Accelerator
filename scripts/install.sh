#!/bin/bash
set -e

# Set Environment variables
export INFRA_DIR="infrastructure"
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

# Configure/render the infrastructure template
helm template eks-accelerator ${INFRA_DIR} \
    --set awsRegion=${AWS_REGION} \
    --set clusterName=${CLUSTER_NAME} \
    --set nodeInstanceType=${NODE_INSTANCE_TYPE:-t3.small} \
    --set vpc.cidr=${VPC_CIDR:-10.10.0.0/16} \
    > ${SCRIPTS_DIR}/generated-cluster-template.yaml

# Extract specific resources from the template
awk '/^apiVersion: eksctl.io\/v1alpha5/{flag=1} flag; /^---/{flag=0}' ${SCRIPTS_DIR}/generated-cluster-template.yaml > ${SCRIPTS_DIR}/cluster.yaml
awk '/^kind: StorageClass/{flag=1} flag; /^---/{flag=0}' ${SCRIPTS_DIR}/generated-cluster-template.yaml > ${SCRIPTS_DIR}/storageclass.yaml
awk '/^apiVersion: karpenter.sh\/v1/{flag=1} flag; /^---/{flag=0}' ${SCRIPTS_DIR}/generated-cluster-template.yaml > ${SCRIPTS_DIR}/nodepool.yaml
awk '/^apiVersion: karpenter.k8s.aws\/v1/{flag=1} flag' ${SCRIPTS_DIR}/generated-cluster-template.yaml > ${SCRIPTS_DIR}/nodeclass.yaml

# Create the eks cluster if cluster doesn't exist
if ! eksctl get cluster --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null 2>&1 ; then
    eksctl create cluster -f ${SCRIPTS_DIR}/cluster.yaml
fi

echo " "
echo "********Waiting for the EKS cluster to be healthy***********"
# Wait until cluster and nodegroup(s) are seen as active and ready
aws eks wait cluster-active --region=${AWS_REGION} --name ${CLUSTER_NAME} 

echo " "
echo "********Patching Storage Class***********"
# Update default storage class to encrypted storage class (standard unencrypted gp2 is aws eks default)
kubectl apply -f ${SCRIPTS_DIR}/storageclass.yaml
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || true

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
echo "********Create Karpenter NodePool and NodeClass***********"
# Karpenter v1.0+ supports native EBS encryption, so no CloudFormation template needed

# Apply Karpenter NodePool and EC2NodeClass
kubectl apply -f ${SCRIPTS_DIR}/nodepool.yaml
kubectl apply -f ${SCRIPTS_DIR}/nodeclass.yaml

echo " "
echo "********Verifying Karpenter Installation***********"
# Wait for Karpenter to be ready
kubectl wait --for=condition=available --timeout=300s deployment/karpenter -n karpenter || {
    echo "Warning: Karpenter deployment not ready yet. Check logs with:"
    echo "kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter"
}

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





