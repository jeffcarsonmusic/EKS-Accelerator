# EKS-Accelerator

A comprehensive, automated solution for deploying production-ready Amazon EKS clusters with Karpenter autoscaling. This solution provides Infrastructure as Code using containerized deployment tools for consistent, reproducible EKS deployments.

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd EKS-Accelerator

# 2. Configure AWS CLI (if not already done)
aws configure

# 3. Deploy the cluster
./eks-accelerator.sh deploy --cluster-name my-cluster --region us-west-2

# 4. Wait for deployment (15-30 minutes)
```

## What This Creates

- **EKS Cluster** (Kubernetes 1.31) with managed node groups
- **Karpenter v1.0.0** for intelligent autoscaling
- **Encrypted GP3 storage** as default storage class
- **VPC with private networking** for security
- **CloudWatch logging** for observability
- **Custom launch templates** for encrypted EBS volumes

## Architecture

The solution uses a containerized deployment approach with:

- **Docker container** with kubectl, eksctl, Helm, and AWS CLI
- **Helm charts** for Infrastructure as Code templating
- **Automated scripts** for complete lifecycle management
- **Karpenter** for sub-minute node provisioning and cost optimization

## Documentation

📚 **Comprehensive documentation is available in the [`docs/`](docs/) directory:**

- **[Getting Started](docs/deployment-guide.md)** - Step-by-step deployment guide
- **[Architecture Overview](docs/architecture.md)** - System design and components
- **[Configuration Reference](docs/configuration.md)** - All configuration options
- **[Directory Structure](docs/directory-structure.md)** - Complete file documentation
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

## Prerequisites

- **Docker Desktop** installed and running
- **AWS Account** with appropriate permissions
- **AWS Credentials** with session token
- **Valid AWS Region** with EKS support

## Repository Structure

```
├── create.sh              # Main deployment script
├── destroy.sh             # Cluster cleanup script
├── docs/                  # Comprehensive documentation
├── ci/docker/             # Container environment and tools
├── infrastructure/        # Helm charts for EKS and Karpenter
└── scripts/              # Automation scripts
```

## Key Features

### 🚀 Fast Deployment
- Automated deployment in 15-30 minutes
- Containerized tools eliminate dependency issues
- Infrastructure as Code for reproducibility

### 💰 Cost Optimized
- Karpenter Spot instance support (up to 90% savings)
- Intelligent bin-packing and consolidation
- Right-sized instance selection

### 🔒 Security First
- Encrypted EBS volumes by default
- Private networking for worker nodes
- IAM roles with least privilege
- VPC isolation and security groups

### 📊 Production Ready
- CloudWatch logging integration
- Multi-AZ deployment support
- Automated health checks
- Comprehensive monitoring

## Quick Commands

```bash
# Deploy cluster
./eks-accelerator.sh deploy --cluster-name my-cluster

# Check status
./eks-accelerator.sh status --cluster-name my-cluster

# Test Karpenter scaling
kubectl apply -f deployment.yaml

# Monitor Karpenter
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Cleanup cluster
./eks-accelerator.sh destroy --cluster-name my-cluster
```

## Support

- **Issues**: Create GitHub issues for bugs or feature requests
- **Documentation**: Check the [docs/](docs/) directory
- **AWS Support**: For AWS service-specific issues
- **Community**: Kubernetes and Karpenter community resources

## Contributing

1. Review the [Architecture Documentation](docs/architecture.md)
2. Check [Configuration Reference](docs/configuration.md) for customization
3. Test changes in isolated environments
4. Update documentation for any changes

## License

[Add your license information here]
