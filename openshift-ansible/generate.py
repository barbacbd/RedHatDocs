import argparse
from logging import getLogger, DEBUG
from getpass import getuser
from os.path import isdir, isfile, exists, dirname, abspath, join
from os import mkdir, chmod, stat, listdir
from shutil import rmtree, copy
import stat as STAT
from pathlib import Path
from yaml import safe_load
from jinja2 import Environment, FileSystemLoader, Template


log = getLogger()
log.setLevel(DEBUG)
generation_dir = "openshift-installer-data"


def get_custom_packages(platform):
    """
    A cloud platform may require additional packages to be installed via yum/dnf. Add
    a list of those here for the platform.
    """
    return {
        "aws": ['awscli']
    }.get(platform, [])


def generate_commands(platform):
    """
    A cloud platform may require additional packages or commands. Add
    a list of those here for the platform.
    """
    statements = []

    if platform == "gcp":
        statements.extend([
            'curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-382.0.0-linux-x86_64.tar.gz',
            'tar -xf google-cloud-cli-382.0.0-linux-x86.tar.gz',
            './google-cloud-sdk/install.sh'
        ])

    return statements


def generate_install_osansible_in_container_script():
    # generate a script that will be added to the container
    data = """#!/bin/bash
./openshift-install create cluster --dir /oi-dev/assets --log-level debug

cd oi-dev;

scripts/oi-byoh.sh bastion 
if [ $? -eq 0 ]; then
    echo "Moving to create ..."
else
    echo "bastion failed, exiting ..."
    exit 1
fi

scripts/oi-byoh.sh create 
if [ $? -eq 0 ]; then
    echo "Moving to prepare ..."
else
    echo "create failed, exiting ..."
    exit 1
fi

scripts/oi-byoh.sh prepare 
if [ $? -eq 0 ]; then
    echo "Moving to scaleup ..."
else
    echo "prepare failed, exiting ..."
    exit 1
fi

scripts/oi-byoh.sh scaleup
if [ $? -eq 0 ]; then
    echo "Success ..."
else
    echo "scaleup failed, exiting ..."
    exit 1
fi
"""
    script_name = "{}/install.sh".format(generation_dir)
    
    with open(script_name, "w+") as ifile:
        ifile.write(data)

    p = Path(script_name)
    p.chmod(p.stat().st_mode | STAT.S_IEXEC) 


def generate_configure_in_container_script(packs, envvars, commands):
    # generate a script that will be added to the container
    data = """#!/bin/bash

yum install -y git {}

{}

{}

# Clone the oi-dev project
if [ ! -d "/oi-dev" ] ; then
    git clone git@github.com:jstuever/oi-dev.git;
    cd oi-dev/;
    mkdir assets;
    cd -;
else
    echo "oi-dev already exists ...";
fi

"""
    for i in range(len(envvars)):
        if not envvars[i].startswith("export"):
            envvars[i] = "export " + envvars[i]
    
    script_name = "{}/configure.sh".format(generation_dir)
    
    with open(script_name, "w+") as ifile:
        ifile.write(data.format(" ".join(packs), "\n".join(envvars), "\n".join(commands)))

    p = Path(script_name)
    p.chmod(p.stat().st_mode | STAT.S_IEXEC) 

    
def generate_install_base_install_script(platform, os_installer_dir, os_image_name, custom_image_name, custom_image_tag):
    # generate the script that will be used to create a container from the image
    data = """#!/bin/bash

set -eux

installer_binary={}/bin/openshift-install

podman run --rm -it                               \\
    -v $installer_binary:/openshift-install    \\
    -v "/home/{}/.{}":/root/.{}                         \\
    -e OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE={} \\
    -e KUBECONFIG="/cluster/auth/kubeconfig"             \\
    {}:{} /bin/bash
    """.format(
        os_installer_dir, # pre podman-command
        getuser(), platform, platform, # line 2
        os_image_name, # line 3
        custom_image_name, custom_image_tag # line 5
    )

    script_name = "{}/connect.sh".format(generation_dir)

    with open(script_name, 'w+') as ifile:
        ifile.write(data)

    p = Path(script_name)
    p.chmod(p.stat().st_mode | STAT.S_IEXEC) 

if __name__ == "__main__":
    with open("config.yaml", "r") as config:
        yaml_data = safe_load(config)

    ssh_file = yaml_data["ssh_key_file"]
    
    # read in the ssh data from the file
    ssh_info = None
    if exists(ssh_file) and isfile(ssh_file):
        with open(ssh_file, 'r') as s:
            ssh_info = s.read()

        if ssh_info is None:
            log.error("No ssh info found")
            exit(1)
    else:
        log.error("Invalid ssh key file")
        exit(1)

    secrets_file = yaml_data["secrets_file"]
    # read in the secrets data from the file
    secrets_info = None
    if exists(secrets_file) and isfile(secrets_file):
        with open(secrets_file, 'r') as s:
            secrets_info = s.read()

        if secrets_info is None:
            log.error("No secrets info found")
            exit(2)
    else:
        log.error("Invalid secrets file")
        exit(2)

    # reebuild the generation directory where the data should reside
    if isdir(generation_dir):
        log.warning("Removing all data from {}".format(generation_dir))
        rmtree(generation_dir)
        
    # make the directory where everything will go
    log.debug("Creating {}".format(generation_dir))
    mkdir(generation_dir)
        
    # Grab the information from the YAML File
    platform = yaml_data["platform"]
    region = yaml_data["region"]
    base_domain = yaml_data["base_domain"]
    installer_dir = yaml_data["installer"]["dir"]
    os_image = yaml_data["installer"]["image"]
    docker_image_name = yaml_data["docker"]["image_name"]
    docker_image_tag = yaml_data["docker"]["tag"]

    # generate the cluster name
    cluster_name = "{}-test-{}".format(getuser(), platform)

    jinja_data = {}
    jinja_data.update(yaml_data)
    jinja_data["cluster_name"] = cluster_name
    jinja_data["pull_secret"] = secrets_info
    jinja_data["ssh_key"] = ssh_info
    
    # using the template and the config data to generate the install-config
    p = dirname(abspath(__file__)) + "/../templates/{}/".format(platform)
    j2_files = [dirf for dirf in listdir(p) if isfile(join(p, dirf)) and dirf.endswith(".j2")]
    if j2_files:
        j2_file = j2_files[0]
        log.debug("Using template: {}".format(j2_file))
    else:
        log.error("No .j2 templates found")
        exit(3)

    with open(join(p, j2_file), "r") as jfile:
        template = Template(jfile.read())
    output = template.render(jinja_data)
    with open("{}/{}".format(generation_dir, j2_file.replace(".j2", "")), "w+") as ic:
        ic.write(output)

    # generate the public and private filenames and add them to the dockerfile
    sp = ssh_file.split("/")
    _ssh_filename = sp[len(sp)-1]

    if _ssh_filename.endswith(".pub"):
        public_file = _ssh_filename
        private_file = _ssh_filename.replace(".pub", "")
    else:
        private_file = _ssh_filename
        public_file = _ss_filename + ".pub"

    with open("Dockerfile.j2", "r") as jfile:
        template = Template(jfile.read())
    output = template.render({"PUBLIC_KEY_FILENAME": public_file, "PRIVATE_KEY_FILENAME": private_file})
    with open("{}/Dockerfile".format(generation_dir), "w+") as ic:
        ic.write(output)
        
    creds_dir = "/home/{}/.{}".format(getuser(), platform)
    log.debug("Set the credentials directory to {}".format(creds_dir))

    if not isdir(creds_dir):
        log.error("{} does not exist".format(creds_dir))
        exit(1)
        
    generate_install_osansible_in_container_script()
    generate_install_base_install_script(platform, installer_dir, os_image, docker_image_name, docker_image_tag)

    packs = get_custom_packages(platform)
    envvars = ["{}={}".format(k, v) for k, v in yaml_data["env"].items()]
    commands = generate_commands(platform)
    generate_configure_in_container_script(packs, envvars, commands)

    print("Execute the following command:\n")
    print("cd {} && podman build . -t {}:{}".format(generation_dir, docker_image_name, docker_image_tag))
