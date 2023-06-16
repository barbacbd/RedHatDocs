# syntax=docker/dockerfile:1.3-labs
from fedora:latest

MAINTAINER Brent Barbachem <barbacbd@gmail.com>

LABEL name="openshift-ansible" \
      summary="Openshift Ansible tool for personal use" \
      description="An image for personal use of openshift-ansible"

# update and install new packages
RUN yum update -y
RUN yum install -y jq wget ncurses python3-pip unzip groff git time emacs bind-utils

# Copy over all of the data from root to /
COPY root /

# Copy over all of the data from usr to /usr
COPY usr /usr

# Create the Downloads directory to hold all of the CLI data
RUN mkdir Downloads

# Download the AWS CLI and add run the install
RUN cd /Downloads && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    cd -

# Download the Google Cloud CLI and add the data to the path
RUN cd /Downloads && \
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-432.0.0-linux-x86_64.tar.gz && \
    tar -xvzf google-cloud-cli-432.0.0-linux-x86_64.tar.gz && \
    cd google-cloud-sdk/bin && \
    export PATH=$PWD:$PATH && \
    cd -

RUN python3 -m pip install pip --upgrade && \
    python3 -m pip install ansible-core && \
    ansible-galaxy collection install amazon.aws && \
    ansible-galaxy collection install google.cloud && \
    ansible-galaxy collection install azure.azcollection && \
    pip install -r /root/.ansible/collections/ansible_collections/amazon/aws/requirements.txt && \
    pip install -r /root/.ansible/collections/ansible_collections/google/cloud/requirements.txt && \
    pip install -r /root/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt

# install the version of azure cli that will work with the other azure packages
RUN python3 -m pip install azure-cli==2.45.0 azure-cli-core==2.45.0 azure-cli-telemetry==1.0.8 --no-deps

# Grab the openshift client, unpack it and move it to the bin for use
RUN cd /Downloads && \
    wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz && \
    tar -xvzf openshift-client-linux.tar.gz && \
    mv oc /usr/bin/ && \
    mv kubectl /usr/bin && \
    cd -

# create a directory that will hold the source code/projects
RUN mkdir devel

# Copy over all of the data from usr to /usr
COPY devel /devel
RUN ln -s /devel/openshift-ansible /devel/openshift-ansible-assistant/openshift-ansible && \
    mkdir -p /devel/openshift-ansible-assistant/assets


ENV AWS_PROFILE=openshift-dev
ENV OC_TOKEN="1Zzp7_e8hcJtfNkKMQYwU5g8ZMKOzQy5cbkiItUe50I"
ENV CLOUDSDK_PYTHON="/usr/bin/python3"
ENV AZURE_PROFILE="/root/.azure/osServicePrincipal.json"
# NOTE:
# This is specific to the current installation but should be changed for others
ENV GOOGLE_APPLICATION_CREDENTIALS=/.gcp/bbarbach-norm-gcp-key.json

RUN echo "alias ll='ls -la'" >> /root/.bashrc
RUN echo "if [ -f '/Downloads/google-cloud-sdk/path.bash.inc' ]; then . /Downloads/google-cloud-sdk/path.bash.inc; fi" >> /root/.bashrc
RUN echo "if [ -f '/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . /Downloads/google-cloud-sdk/completion.bash.inc; fi" >> /root/.bashrc

RUN source /root/.bashrc

# set mirror
RUN ln -s /oi/ /root/oi 

# copy the files over
RUN cp /.ssh/* /root/.ssh

# configuration for aws
RUN ln -s /.aws /root/.aws
# this is only needed if the user for the system is not set.
# BE ADVISED: change the value below for other users (this is the name of the key in aws).
RUN echo "export OI_AWS_KEY_NAME=bbarbach" >> /root/.bashrc

# configuration for azure
RUN ln -s /.azure /root/.azure

# Set all of the GCP variables through gcloud
RUN ln -s /.gcp /root/.gcp
ENV PATH $PATH:/Downloads/google-cloud-sdk/bin
RUN gcloud auth activate-service-account $(cat /.gcp/osServiceAccount.json | jq -r '.client_email') --key-file /.gcp/osServiceAccount.json
RUN gcloud config set account $(cat /.gcp/osServiceAccount.json | jq -r '.client_email')
RUN gcloud config set project openshift-dev-installer
RUN gcloud config set compute/region us-east1
RUN gcloud config set compute/zone us-east1-b