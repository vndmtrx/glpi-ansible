#!/usr/bin/env bash

# Comando para entrar nas máquinas:
# - ssh -F ssh_config 172.28.0.1

set -euo pipefail

function main() {
    CFG="./ansible/.ansible.cfg"
    chmod 0600 id_ed25519

    readonly tem_monitoramento=$(verificar_monitoramento)

    if [ "${tem_monitoramento}" = "true" ]; then
        echo "Máquina de monitoramento detectada. Instalando servidor monitoramento..."
        ANSIBLE_CONFIG="$CFG" ansible-playbook "./ansible/monitoramento.yml" --tags "sistema,monitoramento"
    fi

    ANSIBLE_CONFIG="$CFG" ansible-playbook "./ansible/playbook.yml" --tags todas

    #ANSIBLE_CONFIG="$CFG" ansible-playbook "./ansible/playbook.yml" -v --tags sistema
    #criar_snapshot 01_sistema_pronto

    if [ "${tem_monitoramento}" = "true" ]; then
        echo "Máquina de monitoramento detectada. Instalando componentes de monitoramento nos hosts..."
        ANSIBLE_CONFIG="$CFG" ansible-playbook "./ansible/monitoramento.yml" --tags monitoramento_nos
    fi
}

function verificar_monitoramento() {
    local ip_monitoramento
    ip_monitoramento=$(ANSIBLE_CONFIG="$CFG" ansible-inventory --list | python3 -c 'import sys,json; data=json.load(sys.stdin); print(data["_meta"]["hostvars"][data["monitoramento"]["hosts"][0]]["ansible_host"])')
    nc -z -w 2 "$ip_monitoramento" 22 >/dev/null 2>&1 && echo "true" || echo "false"
}

function criar_snapshot() {
    local base_dir=$(basename $(pwd))
    local snapshot_name=$1
    local vms=$(vagrant status | grep running | awk '{print $1}')
    
    vagrant halt
    
    for vm in $vms; do
        echo "Criando snapshot para $vm..."
        local vm_name="${base_dir}_${vm}"
        
        if virsh -c qemu:///system snapshot-list "$vm_name" | grep -q "$snapshot_name"; then
            echo "Deletando snapshot existente '$snapshot_name' para $vm_name..."
            virsh -c qemu:///system snapshot-delete "$vm_name" "$snapshot_name"
        else
            echo "Nenhum snapshot '$snapshot_name' encontrado para $vm_name. Continuando com a criação..."
        fi
        
        virsh -c qemu:///system snapshot-create-as "$vm_name" "$snapshot_name"
    done
    
    vagrant up 2>&1 | grep -E "Bringing|Error:"
}

function restaurar_snapshot() {
    local base_dir=$(basename $(pwd))
    local snapshot_name=$1
    local vms=$(vagrant status | grep running | awk '{print $1}')
    
    vagrant halt
    
    for vm in $vms; do
        echo "Restaurando snapshot para $vm..."
        local vm_name="${base_dir}_${vm}"

        if virsh -c qemu:///system snapshot-list "$vm_name" | grep -q "$snapshot_name"; then
            virsh -c qemu:///system snapshot-revert "$vm_name" "$snapshot_name" >/dev/null
        fi
    done
    
    vagrant up 2>&1 | grep -E "Bringing|Error:"
}

main