from fedora:latest

MAINTAINER Brent Barbachem <barbacbd@gmail.com>

# The Dockerfile is intended to be used to establish an environment
# for the openshift installer to run. The user will have to provide
# the following packages:
#     openshift-install
#     oc
# wget could be used to grab a prepackaged version of the installer
# and oc. These packages are not grabbed with wget because the
# exact version to be tested is generally a locally built installer.
#
# **IMPORTANT**
# This dockerfile is intended to be executed from /home/$USER
# in order to correctly reference the paths relative to the
# execution point of the build command.
# ex: cd ~/ && docker build -t installer -f /path/to/this/Dockerfile .

LABEL name="openshift-installer" \
      summary="Openshift Installer image for personal use" \
      description="An image for personal use of openshift-installer"

# update and install new packages
RUN yum update -y
RUN yum install -y jq wget ncurses python3-pip unzip groff

# Create the Downloads directory to hold all of the CLI data
RUN mkdir Downloads

# Copy over all of the platform specific credentials. The installer uses this area to store
# the service account information for the platform. Each platform uses this respective area
# to store platform specific details such as profile information.
ADD .gcp .gcp
ADD .aws .aws

# Copy over the location of the secrets file to be used for install configs.
ADD .docker .docker

# Copy over the ssh keys. These will also be used for installation.
ADD .ssh .ssh

# Download the AWS CLI and add run the install
RUN cd /Downloads && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    cd -

# Download the Google Cloud CLI and add the data to the path
RUN cd /Downloads && \
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-492.0.0-linux-x86_64.tar.gz && \
    tar -xvzf google-cloud-cli-492.0.0-linux-x86_64.tar.gz && \
    cd -

RUN echo "export PATH=/Downloads/google-cloud-sdk/bin:$PATH" >> /root/.bashrc

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
ENV GOOGLE_APPLICATION_CREDENTIALS=/.gcp/osServiceAccount.json

RUN echo "if [ -f '/Downloads/google-cloud-sdk/path.bash.inc' ]; then . /Downloads/google-cloud-sdk/path.bash.inc; fi" >> /root/.bashrc
RUN echo "if [ -f '/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . /Downloads/google-cloud-sdk/completion.bash.inc; fi" >> /root/.bashrc
