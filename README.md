# Build Automated Machine Images for MISP

## Requirements

* [VirtualBox](https://www.virtualbox.org)
* [Packer](https://www.packer.io)

## Usage

In the file *scripts/bootstrap.sh*, set the value of ``MISP_BASEURL`` according
to the IP address you will associate to your VM
(for example: http://172.16.100.100).

Launch the generation with the VirtualBox builder:

    $ packer build -only=virtualbox-iso misp.json

A VirtualBox image will be generated and stored in the folder
*output-virtualbox-iso*. You can directly import it in VirtualBox.

If you want to build an image for VMWare you will need to install it and to
use the VMWare builder with the command:

    $ packer build -only=vmware-iso misp.json

You can also launch all builders in parallel.

### Modules activated by default in the VM

* [MISP galaxy](https://github.com/MISP/misp-galaxy)
* [MISP modules](https://github.com/MISP/misp-modules)
* [MISP taxonomies](https://github.com/MISP/misp-taxonomies)

## Automatic export to GitHub

    $ GITHUB_AUTH_TOKEN=<your-github-auth-token>
    $ TAG=v2.4.79
    $ ./upload.sh github_api_token=$GITHUB_AUTH_TOKEN owner=MISP repo=MISP tag=$TAG filename=./output-virtualbox-iso/MISP_demo.ova
