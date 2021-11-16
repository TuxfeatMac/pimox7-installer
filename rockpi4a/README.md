This installer is ment to be for the RockPi4A. It uses the DietPi Bullseye image.

--> https://dietpi.com/downloads/images/DietPi_ROCKPi4-ARMv8-Bullseye.7z



apparmor service is failing...



CT's are working with "workaround"

nano /etc/pve/lxc/100.conf

add:

lxc.apparmor.profile: lxc-default-with-nesting



unable to run VM's

kvm_arm_vcpu_init failed: Invalid argument

Use of uninitialized value $tpmpid in concatenation (.) or string at /usr/share/perl5/PVE/QemuServer.pm line 5491.
