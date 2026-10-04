[management]
vm-management ansible_host=192.168.137.5

[gitlab]
vm1 ansible_host=${vm1_ip}

[application]
vm2 ansible_host=${vm2_ip}

[wazuh]
vm3 ansible_host=${vm3_ip}

[internal:children]
gitlab
application
wazuh

[management:vars]
ansible_user=devsecops
ansible_ssh_private_key_file=/home/devsecops/.ssh/wsl2_management_key

[gitlab:vars]
ansible_user=gitlab
ansible_ssh_private_key_file=/home/devsecops/.ssh/management_ansible_key

[application:vars]
ansible_user=app
ansible_ssh_private_key_file=/home/devsecops/.ssh/management_ansible_key

[wazuh:vars]
ansible_user=siem
ansible_ssh_private_key_file=/home/devsecops/.ssh/management_ansible_key

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
