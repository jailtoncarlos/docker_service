#!/bin/bash
# Função para verificar e carregar o script de utilitários
function check_and_load_utils() {
  RED_COLOR='\033[0;31m'     # Cor vermelha para erros
  NO_COLOR='\033[0m'         # Cor neutra para resetar as cores no terminal

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  utils_sh="$script_dir/scripts/utils.sh"

  if [ ! -f "$utils_sh" ]; then
    echo -e "$RED_COLOR DANG: Shell script $utils_sh não existe.\nEsse arquivo possui as funções utilitárias necessárias.\nImpossível continuar!$NO_COLOR"
    exit 1
  else
    source "$utils_sh"
  fi
}

function configure_path_and_alias() {
    local current_file_name=$(basename $0)
    # Obter o diretório do script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Detectar o shell em uso
    local shell_user=$(basename "$SHELL")
    # Escolher o arquivo de configuração com base no shell
    local arquivo_conf=""

    if [[ "$shell_user" == "bash" ]]; then
        arquivo_conf="$HOME/.bashrc"
    elif [[ "$shell_user" == "zsh" ]]; then
        arquivo_conf="$HOME/.zshrc"
    else
        echo_error "Shell não suportado. Apenas bash e zsh são suportados."
        exit 1
    fi

    # Verificar se o diretório já está no PATH
    if ! grep -Fxq "export PATH=\"\$PATH:${script_dir}\"" "$arquivo_conf"; then
        # Se não estiver, adicionar o diretório ao arquivo de configuração
        echo ">>> export PATH=\"\$PATH:${script_dir}\"" >> "$arquivo_conf"
        echo "O diretório $script_dir foi adicionado ao PATH no arquivo $arquivo_conf."

        # Recarregar o arquivo de configuração
        source "$arquivo_conf"
    else
      echo_warning "O diretório $script_dir já está no PATH."
    fi

    # Verifica se o alias já está configurado
    if ! grep -q "alias sdocker=" "$arquivo_conf"; then
        echo "Criando alias para sdocker"
        echo ">>> alias sdocker=\"${script_dir}/service.sh\"" >> "$arquivo_conf"
        source "$arquivo_conf"
        echo_info "Alias \"sdocker\" criado com sucesso."
    else
        echo_warning "Alias \"sdocker\" já está configurado."
    fi
    echo_success "Commando \"sdocker\" instalado.
       Execute-o no diretório raiz do seu projeto!"
}

verifica_instalacao() {
    # Obter o diretório do script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Obtem o nome do script
    local current_file_name=$(basename $0)

    local script_name=$(basename "$0")
    local path_dir="/home/jailton/workstation/docker_service"

    # Verifica se o nome do arquivo é diferente de 'service.sh'
    if [ "$script_name" != "$current_file_name" ]; then
        # Verifica se o diretório não está no $PATH
        if ! echo "$PATH" | grep -q "$script_dir"; then
            return 1  # Retorna 1 se as condições forem verdadeiras
        fi
    fi

    return 0  # Retorna 0 se uma das condições não for verdadeira
}

check_and_load_utils

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
utils_sh="$script_dir/scripts/utils.sh"
source $utils_sh

_CURRENT_FILE_NAME=$(basename $0)

if [ "$_CURRENT_FILE_NAME" = "install.sh" ]; then
  configure_path_and_alias
fi