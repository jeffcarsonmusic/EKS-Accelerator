#!/bin/bash
set -e

export INFRA_DIR="infrastructure"
export SCRIPTS_DIR="scripts"

source ${SCRIPTS_DIR}/user.env
rm ${SCRIPTS_DIR}/user.env

# update kubeconfig
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

echo " "
echo "********Terminating karpenter owned deployments**********"
##=================================================================================================###
### Clean up Karpenter deployments and karpenter launched nodes
###=================================================================================================###

# get active namespaces with deployments, omitting kube-system, karpenter, and other system namespaces
deployments=$(kubectl get deployment --all-namespaces --no-headers | awk '{print $1}' | grep -v '^kube-system$\|^karpenter$\|^default$' | sort -u)

# test for deployments and delete them if present
if [ -z "$deployments" ]
    then
      echo "No deployments found to delete"
    else
      echo "Found deployments in namespaces $deployments. Let's clean them up before we proceed"
      for each in $deployments
      do
        echo "Deleting resources in the $each namespace"
        kubectl delete deployments --namespace=$each --all
        
      done
fi
sleep 60

echo " "
echo "********Terminating karpenter deployed nodes**********"
# get nodes that now have no deployments and delete them. using the CLI here since "kubectl delete nodes -l karpenter.sh/provisioner-name" shown in the docs worked inconsistently/unpredictably.
karp_nodes=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --filters "Name=tag:karpenter.sh/provisioner-name,Values=*" --region $AWS_REGION --output text)

if [ -n "$karp_nodes" ]
    then
      echo "Deleting $karp_nodes"
      aws ec2 terminate-instances --instance-ids $karp_nodes --region ${AWS_REGION} 2>&1 > /dev/null
      aws ec2 wait instance-terminated --instance-ids $karp_nodes --region ${AWS_REGION} 2>&1 > /dev/null
      echo "Finished deleting karpenter nodes"
    else
        echo "No nodes found"
fi

# delete Karpenter resources (NodePool and NodeClass)
kubectl delete nodepool --all || true
kubectl delete ec2nodeclass --all || true

# ensure ec2 spot service linked role is created for karpenter auto-provisioning/scaling to work
aws iam delete-service-linked-role --aws-service-name spot.amazonaws.com 2> /dev/null || true

echo " "
echo "********Termninating EKS cluster***********"
##=================================================================================================###
### Delete EKS cluster - tears down the EKS cluster via eksctl. 
###=================================================================================================###


# test for orphaned ENI's and manually delete if orphaned on karpenter delete. Once karpenter tear down that is part of eksctl above stops orphaning these, this can go away
orphaned_eni_test=$(aws ec2 describe-network-interfaces  --region $AWS_REGION --filters "Name=tag-key, Values=node.k8s.amazonaws.com/instance_id" "Name=status, Values=available" --query "NetworkInterfaces[].[NetworkInterfaceId]
" --output text)

for item in $orphaned_eni_test; do
  aws ec2 delete-network-interface --network-interface-id $item --region $AWS_REGION
done

# delete the EKS cluster and retry the delete in the event that it fails. 
attempts=1
until eksctl delete cluster --region ${AWS_REGION} --name ${CLUSTER_NAME} --force --wait 2>/dev/null
do 
    echo "Attempt ${attempts} to delete the EKS cluster was not successful. Trying again in 5 minutes..."
    sleep 300
    if [[ $attempts -ge 5 ]]; then
        echo "Manual EKS Cluster cleanup is required at this time."
        echo "Navigate to the AWS console and manually delete the eksctl-${CLUSTER_NAME}-* CloudFormation stack(s)."
    fi
  ((attempts++))
done 

# delete karpenter policy stack 
aws cloudformation delete-stack --stack-name eksctl-${CLUSTER_NAME}-karpenter --region=${AWS_REGION}
aws cloudformation wait stack-delete-complete --stack-name eksctl-${CLUSTER_NAME}-karpenter --region=${AWS_REGION}

echo "Everything has been cleaned up"