FROM alpine:3.21

#ENV TERRAFORM_VERSION 1.5.6
ENV KUBE_LATEST_VERSION=v1.31.0
ENV KUBE_RUNNING_VERSION=v1.31.0
ENV HELM_VERSION=v3.16.4
ENV ISTIO_VERSION=1.24.0
ENV EKSCTL_VERSION=0.210.0

# Update the apk install:
RUN apk --update --no-cache add \
  bash \
  ca-certificates \
  curl \
  jq \
  git \
  openssh-client \
  python3 \
  py3-pip \
  aws-cli \
  groff \
  tar \
  openssl \
  wget

RUN pip3 install --break-system-packages boto3 requests

# Install Terraform
#RUN cd /usr/local/bin && \
#    curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/#terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
#    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
#    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install kubectl
RUN curl -L https://dl.k8s.io/release/${KUBE_RUNNING_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
  chmod +x /usr/local/bin/kubectl

# Install helm
RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
  && chmod +x /usr/local/bin/helm

#install istio
#RUN curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=x86_64 sh -
#ENV PATH="$PATH:/istio-$ISTIO_VERSION/bin"

# Install eksctl
RUN curl --silent --location https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_$(uname -s)_amd64.tar.gz | tar xz -C /usr/local/bin

#Install Ansible 
#RUN apk add ansible

WORKDIR /work
ADD scripts ./scripts
ADD infrastructure ./infrastructure
COPY ["scripts/install.sh", "scripts/uninstall.sh", "scripts/user.env", "./"]
CMD ["bash", "scripts/install.sh"]
