# Troubleshooting Guide

## Common Issues and Solutions

This guide covers the most common issues encountered when deploying and operating EKS clusters with the simplified EKS-Accelerator, including solutions for the new unified command structure.

## Deployment Issues

### Docker Build Failures

#### Issue: Alpine Package Installation Errors

```bash
ERROR: unable to select packages:
  aws-cli (no such package):
    required by: world[aws-cli]
```

**Cause**: Alpine repository issues or package name changes

**Solution**:

```bash
# Clear Docker cache
docker system prune -a

# Rebuild with latest Alpine packages
docker build --no-cache -t devsecops . -f ci/docker/Dockerfile

# Alternative: Use specific Alpine version
FROM alpine:3.21
```

#### Issue: kubectl Download Failures

```bash
curl: (3) URL rejected: Malformed input to a URL function
```

**Cause**: Deprecated kubectl download URLs

**Solution**: Verify Dockerfile uses correct URLs:

```dockerfile
# Correct URL
RUN curl -L https://dl.k8s.io/release/${KUBE_RUNNING_VERSION}/bin/linux/amd64/kubectl

# NOT the old URL
# https://storage.googleapis.com/kubernetes-release/
```

### AWS Authentication Issues

#### Issue: Invalid Credentials Error

```bash
error: You must be logged in to the server (Unauthorized)
```

**Cause**: AWS CLI not configured or credentials expired

**Solutions**:

1. **Configure AWS CLI**:

   ```bash
   aws configure
   ```

2. **Verify credentials**:

   ```bash
   aws sts get-caller-identity
   ```

3. **Use AWS profile**:

   ```bash
   export AWS_PROFILE=your-profile
   ./eks-accelerator.sh deploy --cluster-name test
   ```

4. **Check IAM permissions**:

   ```bash
   aws iam list-attached-user-policies --user-name <username>
   aws iam list-user-policies --user-name <username>
   ```

#### Issue: AWS CLI Not Configured

```bash
Unable to locate credentials. You can configure credentials by running "aws configure"
```

**Solution**:

```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_SESSION_TOKEN=your-token  # If using temporary credentials
```

### EKS Cluster Creation Issues

#### Issue: Cluster Creation Timeout

```bash
waiting for CloudFormation stack "eksctl-cluster-name-cluster" to reach "CREATE_COMPLETE" status
```

**Diagnosis**:

```bash
# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name eksctl-<cluster-name>-cluster \
  --region <region>

# Check eksctl logs
eksctl utils describe-stacks --region <region> --cluster <cluster-name>
```

**Common Causes and Solutions**:

1. **VPC Limit Exceeded**:

   ```bash
   # Check VPC limits
   aws ec2 describe-account-attributes --attribute-names supported-platforms

   # Solution: Delete unused VPCs or request limit increase
   ```

2. **Insufficient EC2 Capacity**:

   ```bash
   # Try different instance type or region
   # Edit infrastructure/eks-cluster/values.yaml
   nodeInstanceType: "t3.medium"  # Instead of t3.small
   ```

3. **IAM Role Issues**:

   ```bash
   # Verify EKS service role exists
   aws iam get-role --role-name eksServiceRole
   
   # If missing, eksctl will create it automatically
   ```

#### Issue: Node Group Creation Failures

```bash
nodes failed to join the cluster
```

**Diagnosis**:

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name managed-ng-private-1 \
  --region <region>

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --region <region>
```

**Solutions**:

1. **Subnet Issues**:

   ```bash
   # Verify subnets have available IP addresses
   aws ec2 describe-subnets --region <region>
   
   # Solution: Use larger VPC CIDR
   # Edit infrastructure/eks-cluster/values.yaml
   vpc:
     cidr: 10.0.0.0/16  # Instead of 10.10.0.0/16
   ```

2. **Security Group Issues**:

   ```bash
   # Check security group rules
   aws ec2 describe-security-groups --region <region>
   ```

### Karpenter Issues

#### Issue: Karpenter Controller Not Starting

```bash
kubectl get pods -n karpenter
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-5d7c7c9c9d-xxxxx   0/1     Pending   0          5m
```

**Diagnosis**:

```bash
# Check controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Check events
kubectl get events -n karpenter --sort-by='.lastTimestamp'
```

**Common Solutions**:

1. **IRSA (IAM Roles for Service Accounts) Issues**:

   ```bash
   # Verify OIDC provider
   aws eks describe-cluster --name <cluster-name> --region <region> \
     --query 'cluster.identity.oidc.issuer'
   
   # Check if Karpenter role exists
   aws iam get-role --role-name KarpenterControllerIAMRole-<cluster-name>
   ```

2. **Node Selector Issues**:

   ```bash
   # Check if system nodes are tainted
   kubectl describe nodes -l node.kubernetes.io/instance-type
   
   # Solution: Ensure system nodes are available for Karpenter
   ```

#### Issue: Nodes Not Being Provisioned

```bash
# Pods stuck in Pending state
kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
test-deployment-xxxxx    0/1     Pending   0          5m
```

**Diagnosis**:

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i provision

# Check pod events
kubectl describe pod <pod-name>

# Check NodePool status
kubectl get nodepool
```

**Common Solutions**:

1. **Launch Template Issues**:

   ```bash
   # Verify launch template exists
   aws ec2 describe-launch-templates --region <region>
   
   # Check launch template permissions
   aws ec2 describe-launch-template-versions \
     --launch-template-name KarpenterCustomLaunchTemplate \
     --region <region>
   ```

2. **Subnet Discovery Issues**:

   ```bash
   # Check subnet tags
   aws ec2 describe-subnets --region <region> \
     --filters "Name=tag:kubernetes.io/role/internal-elb,Values=1"
   
   # Solution: Ensure subnets are properly tagged
   ```

3. **Instance Type Availability**:

   ```bash
   # Check available instance types
   aws ec2 describe-instance-type-offerings --region <region>
   
   # Solution: Add more instance types to NodePool
   kubectl edit nodepool my-nodepool
   ```

## Runtime Issues

### Storage Issues

#### Issue: PVC Stuck in Pending

```bash
kubectl get pvc
NAME        STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc    Pending                                      gp3            5m
```

**Diagnosis**:

```bash
# Check PVC events
kubectl describe pvc test-pvc

# Check storage class
kubectl get storageclass

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

**Solutions**:

1. **EBS CSI Driver Issues**:

   ```bash
   # Check EBS CSI controller logs
   kubectl logs -n kube-system -l app=ebs-csi-controller
   
   # Restart EBS CSI driver
   kubectl rollout restart -n kube-system deployment/ebs-csi-controller
   ```

2. **IAM Permission Issues**:

   ```bash
   # Check EBS CSI driver service account
   kubectl describe serviceaccount -n kube-system ebs-csi-controller-sa
   
   # Verify IAM role has EBS permissions
   aws iam list-attached-role-policies --role-name AmazonEKS_EBS_CSI_DriverRole
   ```

### Networking Issues

#### Issue: Pods Cannot Communicate

```bash
# Pod-to-pod communication failing
kubectl exec -it pod1 -- ping pod2-ip
# Connection timeout
```

**Diagnosis**:

```bash
# Check network policies
kubectl get networkpolicies -A

# Check security groups
aws ec2 describe-security-groups --region <region>

# Check VPC configuration
aws ec2 describe-vpcs --region <region>
```

**Solutions**:

1. **Security Group Rules**:

   ```bash
   # Check cluster security group
   aws eks describe-cluster --name <cluster-name> --region <region> \
     --query 'cluster.resourcesVpcConfig.securityGroupIds'
   
   # Ensure proper ingress rules exist
   ```

2. **VPC CNI Issues**:

   ```bash
   # Check VPC CNI logs
   kubectl logs -n kube-system -l k8s-app=aws-node
   
   # Check available IP addresses
   kubectl describe nodes | grep -A 5 "Allocatable"
   ```

## Monitoring and Observability

### Missing Logs

#### Issue: CloudWatch Logs Not Appearing

**Diagnosis**:

```bash
# Check cluster logging configuration
aws eks describe-cluster --name <cluster-name> --region <region> \
  --query 'cluster.logging'

# Check log groups
aws logs describe-log-groups --region <region>
```

**Solution**:

```bash
# Enable logging if disabled
aws eks update-cluster-config \
  --name <cluster-name> \
  --region <region> \
  --logging '{"enable":[{"types":["api","audit","authenticator","controllerManager","scheduler"]}]}'
```

### Performance Issues

#### Issue: Slow Node Provisioning

**Diagnosis**:

```bash
# Check Karpenter provisioning times
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i "launched node"

# Check instance startup time
aws ec2 describe-instances --region <region> \
  --filters "Name=tag:karpenter.sh/provisioner-name,Values=*"
```

**Solutions**:

1. **Use Pre-warmed AMIs**:

   ```yaml
   # Custom AMI with pre-installed software
   # Edit launch template to use custom AMI
   ```

2. **Optimize Launch Template**:

   ```bash
   # Remove unnecessary user data
   # Use faster instance types
   # Pre-configure networking
   ```

## Emergency Procedures

### Cluster Recovery

#### Complete Cluster Failure

1. **Assessment**:

   ```bash
   # Check cluster status
   aws eks describe-cluster --name <cluster-name> --region <region>
   
   # Check control plane endpoints
   kubectl cluster-info
   ```

2. **Recovery Options**:

   ```bash
   # Option 1: Restart cluster components
   kubectl get pods -n kube-system
   
   # Option 2: Restore from backup (if available)
   # Option 3: Redeploy cluster
   ./destroy.sh
   ./create.sh
   ```

### Data Recovery

#### Lost PersistentVolumes

```bash
# Check for orphaned EBS volumes
aws ec2 describe-volumes --region <region> \
  --filters "Name=status,Values=available"

# Recover data if snapshots exist
aws ec2 describe-snapshots --region <region> \
  --owner-ids self
```

## Prevention Strategies

### Monitoring Setup

```bash
# Install CloudWatch Agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

# Monitor cluster health
aws eks describe-cluster --name <cluster-name> --region <region> \
  --query 'cluster.status'
```

### Backup Procedures

```bash
# Regular EBS snapshots
aws ec2 create-snapshot --volume-id <volume-id> --description "Regular backup"

# Export cluster configuration
kubectl get all -A -o yaml > cluster-backup.yaml

# Backup etcd (for critical clusters)
# Use Velero or similar backup tools
```

### Regular Maintenance

```bash
# Update cluster version
aws eks update-cluster-version --name <cluster-name> --kubernetes-version 1.31

# Update node groups
aws eks update-nodegroup-version --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>

# Update Karpenter
helm upgrade karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION}
```

## Getting Help

### Using the Script

```bash
# Show help
./eks-accelerator.sh help

# Check cluster status
./eks-accelerator.sh status --cluster-name <name> --region <region>

# Enable debug mode
export DEBUG=true
./eks-accelerator.sh deploy --cluster-name test
```

### Log Collection

```bash
# Collect cluster logs
eksctl utils describe-stacks --region <region> --cluster <cluster-name>

# Collect Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=1000

# Collect system events
kubectl get events -A --sort-by='.lastTimestamp'

# Check Docker container logs
docker ps -a  # Find container ID
docker logs <container-id>
```

### Command-Specific Issues

#### Issue: Script Not Executable

```bash
bash: ./eks-accelerator.sh: Permission denied
```

**Solution**:
```bash
chmod +x eks-accelerator.sh
```

#### Issue: Missing Required Parameters

```bash
Error: --cluster-name is required
```

**Solution**:
```bash
# Always include required parameters
./eks-accelerator.sh deploy --cluster-name my-cluster
```

### Support Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Karpenter Documentation**: https://karpenter.sh/
- **eksctl Documentation**: https://eksctl.io/
- **Kubernetes Troubleshooting**: https://kubernetes.io/docs/tasks/debug-application-cluster/

### Contact Points

- AWS Support (for AWS-related issues)
- Kubernetes Community (for Kubernetes-specific issues)
- Karpenter GitHub Issues (for Karpenter problems)
- eksctl GitHub Issues (for eksctl problems)
- EKS-Accelerator Issues (for tool-specific problems)