[nodes]
%{for node in nodes ~}
${node[0]} ansible_host=${node[1]}
%{ endfor ~}

[nodes:vars]
ansible_conncetion=ssh
ansible_ssh_common_args="-o StrictHostKeyChecking=no"
