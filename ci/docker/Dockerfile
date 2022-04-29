FROM alpine:3.9

ENV KUBE_LATEST_VERSION v1.19.1
ENV KUBE_RUNNING_VERSION v1.16.15
ENV HELM_VERSION v3.2.4
ENV AWSCLI 1.22.49
#ENV TERRAFORM_VERSION 0.13.4
ENV ISTIO_VERSION 1.8.1
ENV EKSCTL_VERSION 0.82.0

RUN apk --update --no-cache add \
  bash \
  ca-certificates \
  curl \
  jq \
  git \
  openssh-client \
  python3 \
  tar \
  openssl \
  wget

RUN pip3 install --upgrade pip
RUN pip3 install boto3 requests awscli==${AWSCLI}


# Install Terraform
#RUN cd /usr/local/bin && \
#    curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/#terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
#    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
#    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install kubectl
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_RUNNING_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Install helm
RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
  && chmod +x /usr/local/bin/helm

# Install latest kubectl
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl_latest \
  && chmod +x /usr/local/bin/kubectl_latest

#install istio
RUN curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=x86_64 sh -
ENV PATH "$PATH:/istio-$ISTIO_VERSION/bin"

# Install eksctl
RUN curl --silent --location https://github.com/weaveworks/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_$(uname -s)_amd64.tar.gz | tar xz -C /usr/local/bin

#Install Ansible 
#RUN apk add ansible

WORKDIR /work
ADD scripts ./scripts
ADD infrastructure ./infrastructure
COPY ["scripts/install.sh", "scripts/uninstall.sh", "scripts/user.env", "./"]
CMD ["bash", "scripts/install.sh"]
