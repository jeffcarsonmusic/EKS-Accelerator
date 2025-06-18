# Configuration Reference

## Overview

This document provides a comprehensive reference for all configuration options available in the EKS-Accelerator. The system uses Helm charts with values files to provide flexible, templated infrastructure deployment.

## Configuration Hierarchy

```
Configuration Sources (in order of precedence):
1. Command line parameters (create.sh inputs)
2. values.yaml files (per chart)
3. Default template values
4. Built-in defaults
```

## Main Configuration Files

### Cluster Configuration

#### File: `infrastructure/values.yaml`

**Purpose**: Primary EKS cluster configuration

```yaml
# AWS Configuration
awsRegion: "us-west-2"              # AWS region for deployment
clusterName: "devsecops-cluster"    # EKS cluster name
eksVersion: "1.31"                  # Kubernetes version

# Node Configuration  
nodeInstanceType: "t3.small"       # Instance type for managed nodes

# Network Configuration
vpc:
  cidr: 10.10.0.0/16               # VPC CIDR block
```

#### Configuration Options

##### AWS Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `awsRegion` | string | `"us-west-2"` | AWS region for all resources |
| `clusterName` | string | `"devsecops-cluster"` | EKS cluster name (3-30 chars) |
| `eksVersion` | string | `"1.31"` | Kubernetes version |

**Valid Regions**:
- `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2`
- `eu-west-1`, `eu-west-2`, `eu-central-1`
- `ap-southeast-1`, `ap-southeast-2`, `ap-northeast-1`

**Supported EKS Versions**:
- `1.31` (recommended)
- `1.30` (supported)
- `1.29` (legacy)

##### Node Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nodeInstanceType` | string | `"t3.small"` | EC2 instance type for managed nodes |

**Recommended Instance Types**:

**Development**:
- `t3.small` (2 vCPU, 2 GB RAM) - Minimal cost
- `t3.medium` (2 vCPU, 4 GB RAM) - Balanced

**Production**:
- `t3.large` (2 vCPU, 8 GB RAM) - Standard workloads
- `m5.large` (2 vCPU, 8 GB RAM) - General purpose
- `c5.large` (2 vCPU, 4 GB RAM) - Compute optimized

##### Network Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vpc.cidr` | string | `"10.10.0.0/16"` | VPC CIDR block |

**CIDR Planning**:

```yaml
# Small deployment (up to 100 nodes)
vpc:
  cidr: 10.10.0.0/16    # 65,536 IPs

# Medium deployment (up to 500 nodes)  
vpc:
  cidr: 10.0.0.0/16     # 65,536 IPs

# Large deployment (1000+ nodes)
vpc:
  cidr: 172.16.0.0/12   # 1,048,576 IPs
```

### Karpenter Launch Template Configuration

#### File: `infrastructure/karpenter-launch-template/values.yaml`

```yaml
# Cluster Integration
awsRegion: "us-west-2"
clusterName: "devsecops-cluster"

# Storage Configuration
volumeSize: "20"          # EBS volume size in GB
volumeType: "gp3"         # EBS volume type
encrypted: "true"         # Enable EBS encryption
```

#### Storage Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `volumeSize` | string | `"20"` | Root volume size in GB |
| `volumeType` | string | `"gp3"` | EBS volume type |
| `encrypted` | string | `"true"` | Enable encryption |

**Volume Types**:

```yaml
# Cost-optimized
volumeType: "gp3"    # Latest generation, best price/performance
volumeSize: "20"     # Minimum for most workloads

# Performance-optimized  
volumeType: "io2"    # High IOPS for demanding workloads
volumeSize: "100"    # Larger for high-performance needs

# Budget-optimized
volumeType: "gp2"    # Previous generation, lower cost
volumeSize: "20"     # Minimal sizing
```

### Karpenter Provisioner Configuration

#### File: `infrastructure/karpenter-provisioner/values.yaml`

```yaml
clusterName: "devsecops-cluster"
```

#### File: `infrastructure/karpenter-provisioner/templates/provisioner.yaml`

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
spec:
  template:
    spec:
      # Instance Configuration
      providerConfig:
        launchTemplate:
          name: KarpenterCustomLaunchTemplate
      
      # Network Selection
      subnetSelector:
        kubernetes.io/role/internal-elb: '1'
      securityGroupSelector:
        karpenter.sh/discovery: {{ .Values.clusterName }}
      
      # IAM Configuration
      instanceProfile: eksctl-KarpenterNodeInstanceProfile-{{ .Values.clusterName }}
  
  # Resource Constraints
  constraints:
    - key: karpenter.sh/capacity-type
      operator: In
      values: [spot]  # or [spot, on-demand]
```

#### Karpenter Constraints

##### Capacity Type

```yaml
# Spot instances only (cost-optimized)
constraints:
  - key: karpenter.sh/capacity-type
    operator: In
    values: [spot]

# Mixed capacity (balanced)
constraints:
  - key: karpenter.sh/capacity-type
    operator: In
    values: [spot, on-demand]

# On-demand only (reliability-focused)
constraints:
  - key: karpenter.sh/capacity-type
    operator: In
    values: [on-demand]
```

##### Instance Types

```yaml
# Specific instance types
constraints:
  - key: node.kubernetes.io/instance-type
    operator: In
    values: [t3.medium, t3.large, t3.xlarge]

# Instance families
constraints:
  - key: node.kubernetes.io/instance-type
    operator: In
    values: [t3.*, m5.*, c5.*]

# Exclude specific types
constraints:
  - key: node.kubernetes.io/instance-type
    operator: NotIn
    values: [t3.nano, t3.micro]
```

##### Architecture

```yaml
# x86_64 only
constraints:
  - key: kubernetes.io/arch
    operator: In
    values: [amd64]

# ARM support
constraints:
  - key: kubernetes.io/arch
    operator: In
    values: [amd64, arm64]
```

## Advanced Configuration

### EKS Cluster Template

#### File: `infrastructure/eks-cluster/templates/cluster.yaml`

##### Managed Node Groups

```yaml
managedNodeGroups:
  - name: managed-ng-private-1
    # Instance Configuration
    instanceType: {{ .Values.nodeInstanceType }}
    
    # Scaling Configuration
    minSize: 1
    desiredCapacity: 2
    maxSize: 4
    
    # Storage Configuration
    volumeType: gp3
    volumeSize: 20
    volumeEncrypted: true
    
    # Network Configuration
    privateNetworking: true
    
    # Update Configuration
    updateConfig:
      maxUnavailable: 2
    
    # Labels and Tags
    labels:
      role: worker
    tags:
      nodegroup-role: worker
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/{{ .Values.clusterName }}: "owned"
```

**Scaling Options**:

```yaml
# Development Environment
minSize: 1
desiredCapacity: 1
maxSize: 3

# Production Environment
minSize: 2
desiredCapacity: 3
maxSize: 10

# High Availability
minSize: 3
desiredCapacity: 6
maxSize: 20
```

##### Add-ons Configuration

```yaml
addons:
- name: aws-ebs-csi-driver
  version: 1.44.0
  attachPolicy:
    Statement:
    - Effect: Allow
      Action:
      - ec2:CreateSnapshot
      - ec2:AttachVolume
      - ec2:DetachVolume
      # ... additional permissions
      Resource: "*"
```

**Available Add-ons**:

```yaml
# EBS CSI Driver (required for persistent storage)
- name: aws-ebs-csi-driver
  version: 1.44.0

# VPC CNI (installed by default)
- name: vpc-cni
  version: v1.15.0-eksbuild.2

# CoreDNS (installed by default)
- name: coredns
  version: v1.10.1-eksbuild.5

# kube-proxy (installed by default)
- name: kube-proxy
  version: v1.28.1-eksbuild.1
```

##### CloudWatch Logging

```yaml
cloudWatch:
  clusterLogging:
    enableTypes: ["audit", "api", "authenticator", "controllerManager"]
    logRetentionInDays: 7
```

**Logging Options**:

```yaml
# Minimal logging (cost-optimized)
enableTypes: ["api"]
logRetentionInDays: 1

# Standard logging
enableTypes: ["audit", "api", "authenticator"]
logRetentionInDays: 7

# Comprehensive logging (compliance)
enableTypes: ["audit", "api", "authenticator", "controllerManager", "scheduler"]
logRetentionInDays: 30
```

##### Karpenter Integration

```yaml
karpenter:
  version: "1.0.0"
  createServiceAccount: true
```

### Storage Configuration

#### File: `infrastructure/eks-cluster/storageclass.yaml`

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: aws-ebs-csi-driver
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
  # Optional parameters:
  # iops: "3000"
  # throughput: "125"
```

**Storage Class Options**:

```yaml
# High Performance
parameters:
  type: io2
  iops: "10000"
  encrypted: "true"

# Cost Optimized
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"

# Legacy Support
parameters:
  type: gp2
  encrypted: "true"
```

## Environment-Specific Configurations

### Development Environment

```yaml
# infrastructure/eks-cluster/values.yaml
awsRegion: "us-west-2"
clusterName: "dev-cluster"
eksVersion: "1.31"
nodeInstanceType: "t3.small"

vpc:
  cidr: 10.10.0.0/16
```

```yaml
# Karpenter configuration for development
constraints:
  - key: karpenter.sh/capacity-type
    operator: In
    values: [spot]  # Cost optimization
  - key: node.kubernetes.io/instance-type
    operator: In
    values: [t3.small, t3.medium]  # Small instances
```

### Staging Environment

```yaml
# infrastructure/eks-cluster/values.yaml
awsRegion: "us-west-2"
clusterName: "staging-cluster"
eksVersion: "1.31"
nodeInstanceType: "t3.medium"

vpc:
  cidr: 10.20.0.0/16
```

```yaml
# Karpenter configuration for staging
constraints:
  - key: karpenter.sh/capacity-type
    operator: In
    values: [spot, on-demand]  # Mixed capacity
  - key: node.kubernetes.io/instance-type
    operator: In
    values: [t3.medium, t3.large, m5.large]
```

### Production Environment

```yaml
# infrastructure/eks-cluster/values.yaml
awsRegion: "us-east-1"
clusterName: "prod-cluster"
eksVersion: "1.31"
nodeInstanceType: "m5.large"

vpc:
  cidr: 10.0.0.0/16
```

```yaml
# Karpenter configuration for production
constraints:
  - key: karpenter.sh/capacity-type
    operator: In
    values: [on-demand, spot]  # Reliability priority
  - key: node.kubernetes.io/instance-type
    operator: In
    values: [m5.large, m5.xlarge, m5.2xlarge, c5.large, c5.xlarge]
```

## Security Configuration

### IAM Configuration

The cluster automatically creates necessary IAM roles:

```yaml
# EKS Cluster Service Role
eksctl-<cluster-name>-cluster-ServiceRole

# Node Instance Role
eksctl-<cluster-name>-nodegroup-managed-ng-private-1-NodeInstanceRole

# Karpenter Controller Role
KarpenterControllerIAMRole-<cluster-name>

# Karpenter Node Instance Profile
eksctl-KarpenterNodeInstanceProfile-<cluster-name>
```

### Security Groups

```yaml
# Cluster Security Group
eksctl-<cluster-name>-cluster::ClusterSecurityGroup

# Shared Node Security Group  
eksctl-<cluster-name>-cluster::SharedNodeSecurityGroup

# Control Plane Security Group
eksctl-<cluster-name>-cluster::ControlPlaneSecurityGroup
```

## Validation and Testing

### Configuration Validation

```bash
# Validate Helm templates
helm template eks-cluster infrastructure/eks-cluster --debug

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f generated-cluster-template.yaml

# Validate CloudFormation template
aws cloudformation validate-template --template-body file://generated-karp-launch-template.yaml
```

### Testing Configuration Changes

```bash
# Test with different values
helm template eks-cluster infrastructure/eks-cluster \
  --set clusterName=test-cluster \
  --set nodeInstanceType=t3.medium \
  --set vpc.cidr=10.50.0.0/16

# Validate generated output
helm template eks-cluster infrastructure/eks-cluster | kubectl apply --dry-run=client -f -
```

## Configuration Best Practices

### 1. Environment Separation

- Use different VPC CIDRs per environment
- Separate AWS accounts for production
- Consistent naming conventions

### 2. Resource Sizing

- Start small and scale based on actual usage
- Monitor resource utilization
- Use appropriate instance types for workload characteristics

### 3. Security

- Always enable EBS encryption
- Use least-privilege IAM policies
- Regular security updates

### 4. Cost Optimization

- Use Spot instances for non-critical workloads
- Right-size instances based on usage patterns
- Enable cluster autoscaling

### 5. Monitoring

- Enable comprehensive logging
- Set up monitoring and alerting
- Regular backup and disaster recovery testing