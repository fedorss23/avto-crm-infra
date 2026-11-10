users:
  - name: ubuntu
    ssh-authorized-keys:
      - ${ssh_public_key}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    passwd: "$6$763wEll4qcc3ggVm$H.dU/.6CNQfIt4OpwY7U2IpqL2Co0QTKKUVFNi94Jsw56T98IysT8PG4n7yyioFU72zpsT/.g4fMf4rz91BMv."
    lock_passwd: false
hostname: ${vm_name}
manage_etc_hosts: true
       