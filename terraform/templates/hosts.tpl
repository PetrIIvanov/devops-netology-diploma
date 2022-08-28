# [nodes] created by terraform
%{for node in nodes ~}
${node[1]} ${node[0]}
%{ endfor ~}
