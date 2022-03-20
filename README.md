# Build Automated Machine Images for MISP

Fork of MISP/misp-packer:20.04

Build a virtual machine for MISP based on Ubuntu 20.04.4 server
(for VirtualBox or VMWare).

Changes:

-   JSON packer file converted to HCL2 with Packer converter.
-   required_plugins defined to allow installation with packer init.
-   Variables separated into "variables.pkr.hcl" file.
-   Other common settings between builders turned into variables and defaults set.
-   Default variable overrides in "variables.auto.pkrvars.hcl" file.
-   VirtualBox modifyvm variables moved to main source block where compatible.
-   Removed VirtualBox modifyvm variables that are setting a value that is already the default.
-   Removed VirtualBox port forwards for Jupyter as it seems it is no longer installed.
-   Removed VirtualBox port forwards for Viper and MISP Dashboard as current install script states they are broken and not installed.
-   Boot command changed as was not working while testing.
-   Addition of `networking.sh` script from the[chef/bento](https://github.com/chef/bento) project to ensure the network interface is set to `eth0`. This carries  the `Apache-2.0 License`.
-   INSTALL.sh needs placing in scripts folder as build scripts which download the file have not been updated.
-   Removed said build scripts.
-   Checksum post-processor is used to create checksums for builds.
-   Removed unused variables (desktop, update, http_proxy, https_proxy, no_proxy).
-   Moved misp sudoers.d config from `users.sh` to late-commands in `user-data`.
-   Renamed `users.sh` containing remaining config to `pre.sh` to be run before install.

Instructions:
-   Read Notes.
-   Run `packer init .` to install required plugins.
-   Place latest [INSTALL.sh]("https://raw.githubusercontent.com/MISP/MISP/2.4/INSTALL/INSTALL.sh") in scripts folder.
-   Run `Packer build --only=vmware-iso.ubuntu .` for vmware build.
-   Run `Packer build --only=virtualbox-iso.ubuntu .` for virtualbox build.
-   Run `Packer build .` to build both.

Notes:
-   Timing is important, different hosts load at different speeds, boot_wait needs changing to suit the build host. Separate variables exist for Virtualbox and VMWare.