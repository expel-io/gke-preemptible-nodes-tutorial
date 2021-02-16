FROM google/cloud-sdk:latest

ARG TERRAFORM_VERSION=0.14.6

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        nano \
        unzip \
        vim \
    && rm -rf /var/lib/apt/lists/*

RUN curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip | funzip > /usr/bin/terraform \
    && chmod +x /usr/bin/terraform

COPY .bashrc /root/

WORKDIR /tutorial
