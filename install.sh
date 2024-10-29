#!/bin/bash

##############################################################################
### Funções
##############################################################################
# Função para verificar e carregar o script de utilitários
function check_and_load_scripts() {
  filename_script="$1"

  RED_COLOR='\033[0;31m'     # Cor vermelha para erros
  NO_COLOR='\033[0m'         # Cor neutra para resetar as cores no terminal

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  scriptsh="$script_dir/${filename_script}"

  if [ ! -f "$scriptsh" ]; then
    echo -e "$RED_COLOR DANG: Shell script $scriptsh não existe.\nEsse arquivo possui as funções utilitárias necessárias.\nImpossível continuar!$NO_COLOR"
    exit 1
  else
    source "$scriptsh"
  fi
}

function configure_path_and_alias() {
    local current_file_name=$(basename $0)
    # Obter o diretório do script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Detectar o shell em uso
    local shell_user=$(basename "$SHELL")
    # Escolher o arquivo de configuração com base no shell
    local arquivo_bashrc=""

    if [ "$shell_user" = "bash" ]; then
        arquivo_bashrc="$HOME/.bashrc"
    elif [ "$shell_user" = "zsh" ]; then
        arquivo_bashrc="$HOME/.zshrc"
    else
        echo_error "Shell não suportado. Apenas bash e zsh são suportados."
        exit 1
    fi

    # Verificar se o diretório já está no PATH
    if ! grep -Fxq "export PATH=\"\$PATH:${script_dir}\"" "$arquivo_bashrc"; then
        # Se não estiver, adicionar o diretório ao arquivo de configuração
        echo ">> export PATH=\"\$PATH:${script_dir}\"\" >> $arquivo_bashrc"
        echo "export PATH=\"\$PATH:${script_dir}\"" >> "$arquivo_bashrc"
        echo "O diretório $script_dir foi adicionado ao PATH no arquivo $arquivo_bashrc."
    else
      echo_warning "O diretório $script_dir já está definida no PATH."
    fi

    # Verifica se o alias já está configurado
    if ! grep -q "alias sdocker=" "$arquivo_bashrc"; then
        echo "Criando alias para sdocker"
        echo ">> alias sdocker=\"${script_dir}/service.sh\"\" >> $arquivo_bashrc"
        echo "alias sdocker=\"${script_dir}/service.sh\"" >> "$arquivo_bashrc"
        echo_info "Alias \"sdocker\" criado com sucesso."
    else
        echo_warning "Alias \"sdocker\" já está configurado."
    fi

    # Recarregar o arquivo de configuração
    echo ">>> source $arquivo_bashrc"
    # Executa o comando source e captura a saída
    source "$arquivo_bashrc"

    echo_success "Commando \"sdocker\" instalado."
    echo_info "Execute o \"sdocker\" no diretório raiz do seu projeto!"
}

function atualiza_dockercompose_volumes() {
    local script_dir="$1"
    local dockercompose_base="$2"

    # Atualiza o path "basedir_script" do volume "- <<basedir_script>>/scripts:/scripts/"
    # para o diretório onde está o arquivo service.sh.
    local volume_script_dir="      - ${script_dir}/scripts:/scripts/"
    if ! grep -q "$volume_script_dir" "$dockercompose_base"; then
        echo ">>> sed -i \"/:\/scripts\//c\\$volume_script_dir\" $dockercompose_base"
        sed -i "/:\/scripts\//c\\$volume_script_dir" "$dockercompose_base"
    else
      echo_warning "Volume \"$(echo $volume_script_dir | xargs)\" já definido no arquivo \"${dockercompose_base}\"."
    fi

    # Atualiza o path "basedir_script" do volume "- <<basedir_script>>/scripts/init_database.sh:/docker-entrypoint-initdb.d/init_database.sh"
    # para o diretório onde está o arquivo service.sh.
    local volume_init_database="      - ${script_dir}/scripts/init_database.sh:/docker-entrypoint-initdb.d/init_database.sh"
    if ! grep -q "$volume_init_database" "$dockercompose_base"; then
        echo ">>> sed -i \"/:\/scripts\//c\\$volume_init_database\" $dockercompose_base"
        sed -i "/init_database.sh/c\\$volume_init_database" "$dockercompose_base"
    else
      echo_warning "Volume \"$(echo $volume_init_database | xargs)\" já definido no arquivo \"${dockercompose_base}\"."

    fi
}

function verifica_instalacao() {
    # Obter o diretório do script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Obtem o nome do script
    local current_file_name=$(basename $0)

    local script_name=$(basename "$0")

    # Verifica se o nome do arquivo é diferente de 'service.sh'
    if [ "$script_name" != "$current_file_name" ]; then
        # Verifica se o diretório não está no $PATH
        if ! echo "$PATH" | grep -q "$script_dir"; then
            return 1  # Retorna 1 se as condições forem verdadeiras
        fi
    fi

    return 0  # Retorna 0 se uma das condições não for verdadeira
}
##############################################################################
### Main
##############################################################################

# Carrega o arquivo externo com as funções
check_and_load_scripts "/scripts/utils.sh"
check_and_load_scripts "/scripts/read_ini.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_CURRENT_FILE_NAME=$(basename $0)

if [ "$_CURRENT_FILE_NAME" = "install.sh" ]; then
  inifile_path="${SCRIPT_DIR}/config.ini"
  echo "inifile_path=$inifile_path"
  dockercompose_base=$(read_ini "$inifile_path" "dockercompose" "python_base" | tr -d '\r')
  atualiza_dockercompose_volumes "$SCRIPT_DIR" "$dockercompose_base"
  configure_path_and_alias
fi