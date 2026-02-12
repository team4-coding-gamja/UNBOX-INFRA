# ArgoCD CMP with Helm and AWS CLI
FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    python3 \
    py3-pip \
    && pip3 install --no-cache-dir awscli --break-system-packages

# Install Helm
RUN curl -fsSL https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz | tar -xz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    rm -rf linux-amd64

# Install ArgoCD CMP server binary
RUN curl -fsSL https://github.com/argoproj/argo-cd/releases/download/v2.9.0/argocd-linux-amd64 -o /usr/local/bin/argocd-cmp-server && \
    chmod +x /usr/local/bin/argocd-cmp-server

# Create argocd user
RUN addgroup -g 1000 argocd && \
    adduser -D -u 1000 -G argocd argocd && \
    mkdir -p /home/argocd/cmp-server/plugins && \
    chown -R argocd:argocd /home/argocd

USER 1000

WORKDIR /home/argocd
