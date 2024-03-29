from fedora:latest

MAINTAINER Brent Barbachem <barbacbd@gmail.com>

LABEL name="openshift-installer" \
      summary="Openshift Installer image for personal use" \
      description="An image for personal use of openshift-installer"

# update and install new packages
RUN yum update -y
RUN yum install -y jq wget ncurses python3-pip unzip

RUN alias ll='ls -la'

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

# Grab the openshift client, unpack it and move it to the bin for use
RUN cd /Downloads && \
    wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz && \
    tar -xvzf openshift-client-linux.tar.gz && \
    mv oc /usr/bin/ && \
    mv kubectl /usr/bin && \
    cd -

ENV AWS_PROFILE=openshift-dev
ENV OC_TOKEN="1Zzp7_e8hcJtfNkKMQYwU5g8ZMKOzQy5cbkiItUe50I"
ENV CLOUDSDK_PYTHON="/usr/bin/python3"
# NOTE:
# This is specific to the current installation but should be changed for others
ENV GOOGLE_APPLICATION_CREDENTIALS=/.gcp/bbarbach-norm-gcp-key.json

RUN echo "alias ll='ls -la'" >> /root/.bashrc
RUN echo "if [ -f '/Downloads/google-cloud-sdk/path.bash.inc' ]; then . /Downloads/google-cloud-sdk/path.bash.inc; fi" >> /root/.bashrc
RUN echo "if [ -f '/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . /Downloads/google-cloud-sdk/completion.bash.inc; fi" >> /root/.bashrc


