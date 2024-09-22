#!/bin/bash
# O erro bad interpreter: No such file or directory ocorre porque o script service.sh foi provavelmente criado
# ou editado em um ambiente Windows, onde o final de linha é CRLF (\r\n), enquanto no Linux o final de linha
# padrão é LF (\n). O caractere ^M representa o \r (Carriage Return) que está causando o problema.
#
# Correção:
# >>> sed -i 's/\r//' service.sh
# >>> sed -i 's/\r//' docker/dev/scripts/utils.sh
# >>> sed -i 's/\r//' docker/dev/scripts/init_database.sh

# garantir que o Git não altere os fins de linha automaticamente ao fazer checkout ou commit.
git config --global core.autocrlf false
PROJECT_ROOT_DIR=$(pwd -P)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega o arquivo externo com as funções
source "$SCRIPT_DIR/install.sh"

check_and_load_utils

# Carrega o arquivo externo com as funções
source "$SCRIPT_DIR/scripts/read_ini.sh"

if ! verifica_instalacao; then
    echo_warning "Utilitário docker service não instalado!
    Execute o comando ./install.sh"
fi

if [ "$PROJECT_ROOT_DIR" = "$SCRIPT_DIR" ]; then
  echo_success "Configurações iniciais do spript definidas com sucesso."
  echo_info "Execute o comando \"sdocker\" no diretório raiz do seu projeto."
  exit 1
else
  echo_info "PROJECT_ROOT_DIR: $PROJECT_ROOT_DIR"
  if ! verificar_comando_inicializacao_ambiente_dev "$PROJECT_ROOT_DIR"; then
      echo_error "Ambiente de desenvolvimento não identificado."
      echo_info "Execute o comando \"sdocker\" no diretório raiz do seu projeto."
      exit 1
  fi
fi

PROJECT_DEV_DIR=$PROJECT_ROOT_DIR

PROJECT_NAME=$(basename $PROJECT_ROOT_DIR)
DEFAULT_BASE_DIR="$PROJECT_ROOT_DIR/$PROJECT_NAME"

PROJECT_ENV_PATH_FILE="${PROJECT_DEV_DIR}/.env"
PROJECT_ENV_FILE_SAMPLE="${PROJECT_DEV_DIR}/.env.sample"
ENV_BASE_FILE_SAMPLE="${SCRIPT_DIR}/env.sample"

##############################################################################
### FUÇÕES UTILITÁRIAS
##############################################################################

function get_server_name() {
  local _input="$1"

  # Verifique se a entrada está vazia
  if [ -z "$_input" ]; then
    return 1
  fi

  _service_name_parse=$(dict_get "$_input" "${DICT_ARG_SERVICE_PARSE[*]}")
  echo "${_service_name_parse:-$_input}"
}

##############################################################################
### GERANDO UM ARQUIVO .env.sample personalizado.
##############################################################################
function verifica_e_configura_env() {
    local env_base_file_sample="$1"
    local project_env_file_sample="$2"
    local project_name="$3"

    local project_root_dir=$(pwd -P)
    local project_dockerfile="${project_root_dir}/Dockerfile"
    local default_base_dir="$project_root_dir/$project_name"
    local settings_sample_local_file="local_settings_sample.py"
    # A estrutura ${VAR/old/new} substitui a primeira ocorrência de old na variável VAR por new
    # Removendo a plavra "_sample". Ex. local_settings_sample.py irá ficar local_settings.py
    local settings_local_file="${settings_sample_local_file/_sample/}"

    # Função para verificar e retornar o caminho correto do arquivo de requirements
    function get_requirements_file() {
        # Verificar se o arquivo requirements.txt existe
        if [[ -f "$project_root_dir/requirements.txt" ]]; then
            echo "requirements.txt"
            return
        fi

        # Verificar se o arquivo requirements/dev.txt existe
        if [[ -f "$project_root_dir/requirements/dev.txt" ]]; then
            echo "requirements/dev.txt"
            return
        fi

        # Verificar se o arquivo requirements/development.txt existe
        if [[ -f "$project_root_dir/requirements/development.txt" ]]; then
            echo "requirements/development.txt"
            return
        fi

        # Caso nenhum arquivo seja encontrado, retornar uma string vazia
        echo ""
    }

    # Definir variáveis de ambiente
    local default_requirements_file=$(get_requirements_file "$project_root_dir")

    # Verificar se o arquivo de exemplo de ambiente existe
    if [ ! -f "${project_env_file_sample}" ]; then
        echo_error "Arquivo ${project_env_file_sample} não encontrado. Impossível continuar!"
        echo_warning "Esse arquivo é o modelo com as configurações mínimas necessárias para os containers funcionarem."
        echo_info "Deseja que este script crie um arquivo modelo padrão para seu projeto?"
        read -p "Pressione 'S' para continuar: " resposta
        resposta=$(echo "$resposta" | tr '[:lower:]' '[:upper:]')  # Converter para maiúsculas

        if [ "$resposta" = "S" ]; then
#            touch $project_env_file_sample
#            echo ">>> cp ${env_base_file_sample} ${project_env_file_sample}"
#            cp "${env_base_file_sample}" ${project_env_file_sample}


            # Definir a sub-rede e o IP do gateway inicial
            local default_vpn_gateway_faixa_ip="172.19.0.0/16"
            local default_vpn_gateway_ip="172.19.0.1"

            # Verificar se o gateway inicial está em uso
            if verificar_gateway_em_uso "$default_vpn_gateway_ip"; then
                echo_warning "IP do gateway $default_vpn_gateway_ip já está em uso."

                # Encontrar um novo IP de gateway disponível
                local resultado=$(encontrar_ip_disponivel "172.19" "16")

                if [ $? -eq 0 ]; then
                    default_vpn_gateway_faixa_ip=$(echo "$resultado" | cut -d ' ' -f 1)
                    default_vpn_gateway_ip=$(echo "$resultado" | cut -d ' ' -f 2)
                    echo_warning "Nova sub-rede e IP de gateway disponíveis: $default_vpn_gateway_faixa_ip, Gateway: $default_vpn_gateway_ip"
                else
                    echo_error "Não foi possível encontrar uma sub-rede ou IP de gateway disponível."
                    exit 1
                fi
            else
                echo_warning "Sub-rede default_vpn_gateway_faixa_ip e gateway $default_vpn_gateway_ip estão disponíveis."
            fi

# Criar o arquivo .env.sample e inserir as variáveis na ordem inversa
cat <<EOF > "$project_env_file_sample"
COMPOSE_PROJECT_NAME=${project_name}
DEV_IMAGE=
GIT_BRANCH_MAIN=master
REQUIREMENTS_FILE=${default_requirements_file}

SETTINGS_SAMPLE_LOCAL_FILE=${settings_sample_local_file}
SETTINGS_LOCAL_FILE=${settings_local_file}
BASE_DIR=${default_base_dir}

DATABASE_NAME=${project_name}
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_HOST=db
DATABASE_PORT=5432
DATABASE_DUMP_DIR=${project_root_dir}/dump

WORK_DIR=/opt/app

DOCKERFILE=${project_dockerfile}
PYTHON_BASE_IMAGE=python:3.12-slim-bullseye
POSTGRES_IMAGE=postgres:16.3

APP_PORT=8000
REDIS_EXTERNAL_PORT=6379
PGADMIN_EXTERNAL_PORT=8001

USER_NAME=$(id -un)
UID=$(id -g)
GID=$(id -u)

VPN_GATEWAY=${default_vpn_gateway_ip}
VPN_GATEWAY_FAIXA_IP=${default_vpn_gateway_faixa_ip}

SERVICES_DEPENDENCIES="
web:node;redis;db
db:pgadmin
"

SERVICES_COMMANDS="
all:deploy;undeploy;redeploy;status;restart;logs;up;down;
web:makemigrations;manage;migrate;shell_plus;debug;build;git;pre-commit
db:psql;wait;dump;restore;copy;
pgadmin:;
redis:
"

COMPOSES_FILES="
all:docker-compose.yml
"
EOF

            echo_success "Arquivo $project_env_file_sample criado."
        fi
    fi

    # Verificar novamente se o arquivo de ambiente foi criado
    if [ ! -f "${project_env_file_sample}" ]; then
        echo_error "Arquivo ${project_env_file_sample} não encontrado. Impossível continuar!"
        echo_warning "Adicione o arquivo $project_env_file_sample no diretório raiz ($project_root_dir) do seu projeto."
        exit 1
    fi
}

verifica_e_configura_env "$ENV_BASE_FILE_SAMPLE" "$PROJECT_ENV_FILE_SAMPLE" "$PROJECT_NAME"

##############################################################################
### EXPORTANDO VARIÁVEIS DE AMBIENTE DO ARQUIVO $PROJECT_DEV_DIR/.env
##############################################################################
configura_env() {
  local project_env_path_file="$1"
  local project_env_file_sample="$2"

  # Verifica se o arquivo .env não existe e procede com a cópia
  if [ ! -f "${project_env_path_file}" ]; then
    echo ">>> cp ${project_env_file_sample}  ${project_env_path_file}"
    cp "${project_env_file_sample}" "${project_env_path_file}"
  fi

  sleep .5

  # Exporta as variáveis de ambiente presentes no arquivo .env
  export $(xargs -0 < "${project_env_path_file}") 2> /dev/null

  # Carrega o conteúdo do arquivo .env diretamente no script
  source "${project_env_path_file}" 2>/dev/null

  # Imprime as variáveis de ambiente
#  imprime_variaveis_env "${project_env_path_file}"
}

configura_env "$PROJECT_ENV_PATH_FILE" "$PROJECT_ENV_FILE_SAMPLE"

##############################################################################
### CONVERTENDO ARRAY DO .ENV NA TAD DICT
##############################################################################
# String multilinha SERVICES_DEPENDENCIES: Quando uma string multilinha como SERVICES_DEPENDENCIES é usada em uma
# iteração (for e in ${SERVICES_DEPENDENCIES[@]}; do), o Bash separa cada linha e trata-a como um único item.
# Como o valor de SERVICES_DEPENDENCIES tem quebras de linha, ele trata cada linha como uma entrada.
#
# Array DICT_SERVICES_DEPENDENCIES: Já o array DICT_SERVICES_DEPENDENCIES contém exatamente os mesmos elementos que foram
# adicionados de forma explícita no loop anterior.
# Como cada linha de SERVICES_DEPENDENCIES foi adicionada como um item separado ao array, o comportamento na iteração
# também será o mesmo, porque o array contém os mesmos elementos que estavam nas linhas da string.
#
# Com array, podemos fazer as seguintes operações
# 1. Acesso a Elementos Específicos: echo "${DICT_SERVICES_DEPENDENCIES[0]}"
# 2. Iteração Elemento por Elemento:
# 3. Adicionar ou Remover Elementos: DICT_SERVICES_DEPENDENCIES+=("new_service")
# 4. Substituição de Elementos Específicos: DICT_SERVICES_DEPENDENCIES[1]="new_value"
# 5. Verificar o Número de Elementos: echo "Total de serviços: ${#DICT_SERVICES_DEPENDENCIES[@]}"
# 6. Ordenação: IFS=$'\n' sorted=($(sort <<<"${DICT_SERVICES_DEPENDENCIES[*]}"))

# Declarações das variáveis de arrays
DICT_COMPOSES_FILES=()
DICT_SERVICES_COMMANDS=()
DICT_SERVICES_DEPENDENCIES=()
DICT_ARG_SERVICE_PARSE=()

#Conversão das string multilinhas para array
convert_multiline_to_array "$COMPOSES_FILES" DICT_COMPOSES_FILES
convert_multiline_to_array "$SERVICES_COMMANDS" DICT_SERVICES_COMMANDS
convert_multiline_to_array "$SERVICES_DEPENDENCIES" DICT_SERVICES_DEPENDENCIES
convert_multiline_to_array "$ARG_SERVICE_PARSE" DICT_ARG_SERVICE_PARSE

##############################################################################
### DEFINIÇÕES DE VARIÁVEIS GLOBAIS
##############################################################################
REVISADO=${REVISADO:-0}

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$PROJECT_NAME}"
GIT_BRANCH_MAIN=${GIT_BRANCH_MAIN:-master}
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-requirements.txt}"

BASE_DIR=${BASE_DIR:-$DEFAULT_BASE_DIR}
SETTINGS_SAMPLE_LOCAL_FILE="${SETTINGS_SAMPLE_LOCAL_FILE:-local_settings_sample.py}"
# A estrutura ${VAR/old/new} substitui a primeira ocorrência de old na variável VAR por new
# Removendo a plavra "_sample". Ex. local_settings_sample.py irá ficar  local_settings.py
SETTINGS_LOCAL_FILE=${SETTINGS_SAMPLE_LOCAL_FILE/_sample/}

DATABASE_NAME=${DATABASE_NAME:-$COMPOSE_PROJECT_NAME}
POSTGRES_USER=${DATABASE_USER:-$POSTGRES_USER}
POSTGRES_PASSWORD=${DATABASE_PASSWORD:-$POSTGRES_PASSWORD}
POSTGRES_DB=${DATABASE_NAME:-$POSTGRES_DB}
POSTGRES_HOST=${DATABASE_HOST:-$POSTGRES_HOST}
POSTGRES_PORT=${DATABASE_PORT:-$POSTGRES_PORT}
#POSTGRESQL="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/"
POSTGRES_DUMP_DIR=${DATABASE_DUMP_DIR:-dump}
DIR_DUMP=${POSTGRES_DUMP_DIR:-dump}

WORK_DIR="${WORK_DIR:-/opt/app}"

PROJECT_DOCKERFILE="${PROJECT_DOCKERFILE:-Dockerfile}"
PYTHON_BASE_IMAGE="${PYTHON_BASE_IMAGE:-3.12-slim-bullseye}"
#DEV_IMAGE="${DEV_IMAGE:-python-nodejs-base}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16.3}"

APP_PORT=${APP_PORT:-8000}
REDIS_EXTERNAL_PORT=${REDIS_EXTERNAL_PORT:-6379}
PGADMIN_EXTERNAL_PORT=${PGADMIN_EXTERNAL_PORT:-8001}

USER_NAME=${USER_NAME:-$(id -un)}
USER_UID=${UID:-$(id -u)}
USER_GID=${GID:-$(id -g)}

VPN_GATEWAY_FAIXA_IP="${VPN_GATEWAY_FAIXA_IP:-172.19.0.0/16}"
VPN_GATEWAY="${VPN_GATEWAY:-172.19.0.2}"

COMMANDS_COMUNS=(up down restart exec run logs shell)

ARG_SERVICE="$1"
ARG_COMMAND="$2"
ARG_OPTIONS="${@:3}"
#SERVICE_NAME=$(get_server_name "${ARG_SERVICE}")
SERVICE_WEB_NAME=$(get_server_name "web")
SERVICE_DB_NAME=$(get_server_name "db")

##############################################################################
### Tratamento para arquivo Dockerfile
##############################################################################
function verifica_e_configura_dockerfile_project() {
    local script_dir="$1"
    local project_root_dir="$2"
    local project_env_path_file="$3"
    local compose_project_name="$4"
    local revisado="$5"
    local dev_image="$6"

    local config_inifile="${script_dir}/config.ini"
    local dockerfile_base_dev_sample="${script_dir}/dockerfiles/Dockerfile-base-python-nodejs-dev"
    local project_dockerfile_sample="${project_root_dir}/Dockerfile.sample"
    local project_dockerfile="${project_root_dir}/Dockerfile"
    local resposta
    local base_image

    if [ ! -f ${project_env_path_file} ]; then
      echo_error "Arquivo #project_env_path_file não encontrado. Impossível continuar!"
      exit 1
    fi

    if [ ! -f "$project_dockerfile_sample" ]; then
      echo_warning "Arquivo $project_dockerfile_sample não encontrado."
    elif [ $revisado -eq 0 ]; then
      echo_warning "Arquivo $project_dockerfile_sample encontrado."
    fi

    if [ ! -f "$project_dockerfile" ]; then
      echo_warning "Arquivo $project_dockerfile não encontrado."
    fi

    if [ $revisado -eq 0 ]; then
      echo_warning "Variável REVISADO=0"
    fi

    if { [[ $revisado -eq 0 ]] && [[ ! -f "$project_dockerfile_sample" ]]; } || [[ ! -f "$project_dockerfile" ]]; then
        echo_info "Deseja que este script crie e/ou substitua arquivo modelo (Dockerfile.sample) para seu projeto?"
        read -p "Pressione 'S' para continuar: " resposta
        resposta=$(echo "$resposta" | tr '[:lower:]' '[:upper:]')
    fi

    if [ ! -f "$project_dockerfile_sample" ]; then

        if [ -z "${dev_image}" ]; then
          echo_error "A variável DEV_IMAGE não está definida no arquivo '${project_env_path_file}'"
          echo_info "Essa variável é usada pelo Dockerfile para definir a imagem base a ser utilizada para construir o contêiner."

          base_image=$(escolher_imagem_base)
          dev_image=$(read_ini $config_inifile images $base_image | tr -d '\r')
          filename=$(read_ini $config_inifile dockerfiles $base_image | tr -d '\r')
          dockerfile_base_dev_sample="${script_dir}/dockerfiles/${filename}"

          echo "base_image: $base_image"
          echo "dev_image: $dev_image"
          echo "dockerfile_base_dev_sample: $dockerfile_base_dev_sample"
        fi

        if [ "$resposta" = "S" ]; then
            echo ">>> cp ${dockerfile_base_dev_sample} ${project_dockerfile_sample}"
            cp $dockerfile_base_dev_sample "${project_dockerfile_sample}"
            echo_success "Arquivo $project_dockerfile_sample criado!"
            sleep 0.5
        else
          echo_warning "Recomendamos criar o arquivo de modelo Dockerfile.sample.
       Com ele, você pode comparar com o Dockerfile do seu projeto."
        fi
    fi

    if [ -z "${dev_image}" ]; then
        echo_error "A variável DEV_IMAGE não está definida no arquivo '${project_env_path_file}'"
        echo_info "Defina o valor dela em '${project_env_path_file}'"
        exit 1
    else
        dev_image="${dev_image:-base_image}"

        if [ -f "$project_dockerfile_sample" ] && ! grep -q "${compose_project_name}-dev" "$project_dockerfile_sample"; then
            # Substitui a primeira linha por "DEV_IMAGE"
#            echo "--- Substituindo a 1a linha por \"ARG DEV_IMAGE=${dev_image}\" no arquivo $project_dockerfile_sample"
#            sed -i "1s|.*|ARG DEV_IMAGE=${dev_image}|" "$project_dockerfile_sample"

            # Substituir a linha que contém "ARG DEV_IMAGE=" pela nova definição
#            echo "--- Substituindo a linha 'ARG DEV_IMAGE=' por 'ARG DEV_IMAGE=${dev_image}' no arquivo $project_dockerfile_sample"
#            sed -i "s|^ARG DEV_IMAGE=.*|ARG DEV_IMAGE=${dev_image}|" "$project_dockerfile_sample"

            echo "--- Substituindo a linha 'DEV_IMAGE=' por 'DEV_IMAGE=${dev_image}' no arquivo $project_env_path_file"
            sed -i "s|^DEV_IMAGE=.*|DEV_IMAGE=${dev_image}|" "$project_env_path_file"

            echo "--- Substituindo \"app-dev\" por \"${compose_project_name}-dev\" no arquivo '${project_dockerfile_sample}'"
            sed -i "s|app-dev|${compose_project_name}-dev|g" "$project_dockerfile_sample"
        fi
    fi

    if [ ! -f "$project_dockerfile" ] && [ -f "$project_dockerfile_sample" ]; then
        echo_warning "Detectamos que existe o arquivo $project_dockerfile_sample, porém não encontramos o arquivo $project_dockerfile."
        echo_info "O arquivo '$project_dockerfile' contém instruções para construção de uma imagem Docker."
        echo_info "Deseja copiar o arquivo de modelo $project_dockerfile para o arquivo definitivo $project_dockerfile_sample?"
        read -p "Pressione 'S' para continuar: " resposta
        resposta=$(echo "$resposta" | tr '[:lower:]' '[:upper:]')

        if [ "$resposta" = "S" ]; then
            echo ">>> cp $project_dockerfile_sample $project_dockerfile"
            cp "$project_dockerfile_sample" "$project_dockerfile"
        fi
    fi

    if [ ! -f "$project_dockerfile" ]; then
        echo_warning "Arquivo $project_dockerfile não encontrado."
        echo_info "Recomendamos criar o arquivo 'Dockerfile' no diretório raiz (${project_root_dir}) do seu projeto."
    fi
}

verifica_e_configura_dockerfile_project "$SCRIPT_DIR" "$PROJECT_ROOT_DIR" "$PROJECT_ENV_PATH_FILE" "$COMPOSE_PROJECT_NAME" "$REVISADO" "$DEV_IMAGE"

##############################################################################
### Tratamento para arquivo docker-compose.yml
##############################################################################
function verifica_e_configura_dockercompose_project() {
    local script_dir="$1"
    local project_root_dir="$2"
    local project_env_path_file="$3"
    local revisado="$4"

    local dockercompose_base="${script_dir}/docker-compose-base.yml"
    local dockercompose_base_dev_sample="${script_dir}/docker-compose-base-sample-node.yml"
    local project_dockercompose_sample="${project_root_dir}/docker-compose.sample.yml"
    local project_dockercompose="${project_root_dir}/docker-compose.yml"

    local volume="      - ${script_dir}/scripts:/scripts/"
    if ! grep -q "$volume" "$dockercompose_base"; then
        echo ">>> sed -i \"/:\/scripts\//c\\$volume\" $dockercompose_base"
        sed -i "/:\/scripts\//c\\$volume" "$dockercompose_base"
    fi

    volume="      - ${script_dir}/scripts/init_database.sh:/docker-entrypoint-initdb.d/init_database.sh"
    if ! grep -q "$volume" "$dockercompose_base"; then
        echo ">>> sed -i \"/:\/scripts\//c\\$volume\" $dockercompose_base"
        sed -i "/init_database.sh/c\\$volume" "$dockercompose_base"
    fi

    if { [[ $revisado -eq 0 ]] && [[ ! -f "$project_dockercompose_sample" ]]; } || [[ ! -f "$project_dockercompose" ]]; then
        echo_warning "Arquivo $project_dockercompose_sample não encontrado."
        echo_info "Esse arquivo é um modelo de configuração docker compose com exemplo básico de como usar a arquitetura \"Docker Service\"."
        echo_info "Deseja que este script crie um arquivo modelo (docker-compose.sample.yml) padrão para seu projeto?"
        read -p "Pressione 'S' para continuar: " resposta
        resposta=$(echo "$resposta" | tr '[:lower:]' '[:upper:]')  # Converter para maiúsculas

        if [ "$resposta" = "S" ]; then
            echo ">>> cp ${dockercompose_base_dev_sample} ${project_dockercompose_sample}"
            cp "${dockercompose_base_dev_sample}" "${project_dockercompose_sample}"
            echo_success "Arquivo $project_dockercompose_sample criado!"
            sleep 0.5
        fi
    fi

    if [ -f "$project_dockercompose_sample" ] && ! grep -q "${project_env_path_file}" "$project_dockercompose_sample"; then
        echo ">>> sed -i \"s|.env.sample|${project_env_path_file}|g\" $project_dockercompose_sample"
        sed -i "s|.env.sample|${project_env_path_file}|g" "$project_dockercompose_sample"
    fi

    if [ ! -f "$project_dockercompose" ] && [ -f "$project_dockercompose_sample" ]; then
        echo_warning "Detectamos que existe o arquivo $project_dockercompose_sample, porém não encontramos o arquivo $project_dockercompose."
        echo_info "O arquivo \"$project_dockercompose\" é um arquivo de configuração usado pela ferramenta \"Docker Compose\" para definir e gerenciar múltiplos contêineres \"Docker\" como um serviço."
        echo_info "Deseja copiar o arquivo de modelo $project_dockercompose_sample para o arquivo definitivo $project_dockercompose?"
        read -p "Pressione 'S' para continuar: " resposta
        resposta=$(echo "$resposta" | tr '[:lower:]' '[:upper:]')

        if [ "$resposta" = "S" ]; then
            echo ">>> cp $project_dockercompose_sample $project_dockercompose"
            cp "$project_dockercompose_sample" "$project_dockercompose"
        fi
    fi

    if [ ! -f "$project_dockercompose" ]; then
        echo_error "Arquivo $project_dockercompose não encontrado."
        echo_info "Crie o arquivo \"docker-compose.yml\" no diretório raiz (${project_root_dir}) do seu projeto."
        exit 1
    fi
}

verifica_e_configura_dockercompose_project "$SCRIPT_DIR" "$PROJECT_ROOT_DIR" "$PROJECT_ENV_PATH_FILE" "$REVISADO"

##############################################################################
### Inserindo varíaveis com valores padrão no início do arquivo .env
###############################################################################
# Só insere caso a variável não exista.

insert_text_if_not_exists "DATABASE_DUMP_DIR=${DATABASE_DUMP_DIR}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "DATABASE_NAME=${DATABASE_NAME}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "VPN_GATEWAY_FAIXA_IP=${VPN_GATEWAY_FAIXA_IP}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "VPN_GATEWAY=${VPN_GATEWAY}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "GID=${USER_GID}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "UID=${USER_UID}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "USER_NAME=${USER_NAME}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "PGADMIN_EXTERNAL_PORT=${PGADMIN_EXTERNAL_PORT}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "REDIS_EXTERNAL_PORT=${REDIS_EXTERNAL_PORT}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "APP_PORT=${APP_PORT}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "REQUIREMENTS_FILE=${REQUIREMENTS_FILE}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "DOCKERFILE=${PROJECT_DOCKERFILE}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "POSTGRES_IMAGE=${POSTGRES_IMAGE}" "$PROJECT_ENV_PATH_FILE"
#insert_text_if_not_exists "BASE_IMAGE=${BASE_IMAGE}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "DEV_IMAGE=${DEV_IMAGE}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "GIT_BRANCH_MAIN=${GIT_BRANCH_MAIN}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "WORK_DIR=${WORK_DIR}" "$PROJECT_ENV_PATH_FILE"
insert_text_if_not_exists "COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}" "$PROJECT_ENV_PATH_FILE"
##############################################################################
### TRATAMENTO DAS VARIÁVEIS DEFINDAS EM .ENV
##############################################################################

#echo "ARG_SERVICE = $ARG_SERVICE"
#echo "ARG_COMMAND = $ARG_COMMAND"
#echo "ARG_OPTIONS = $ARG_OPTIONS"
#echo "SERVICE_NAME = $SERVICE_NAME"
#echo "SERVICE_WEB_NAME = $SERVICE_WEB_NAME"
#echo "SERVICE_DB_NAME = $SERVICE_DB_NAME"
#echo "PROJECT_NAME = $PROJECT_NAME"
#echo "BASE_DIR = $BASE_DIR"

#Se não existir o arquivo ${ENV_PATH_FILE}, copie de $CURRENT_DIRECTORY/.env.dev.sample
if [ "$REVISADO" -eq 0 ]; then
  imprime_variaveis_env $PROJECT_ENV_PATH_FILE
  echo_warning "Acima segue TODO os valores das variáveis definidas no arquivo \"${PROJECT_ENV_PATH_FILE}\"."
  echo "
  Segue abaixo as princípais variáveis:
    * Variável de configuração de caminho de arquivos:
        - BASE_DIR=${BASE_DIR}
        - DATABASE_DUMP_DIR=${DATABASE_DUMP_DIR}
        - REQUIREMENTS_FILE=${REQUIREMENTS_FILE}
          O valor da variável REQUIREMENTS_FILE deve apontar para o diretorio, se existir, e arquivo requiriments.
            Exemplo: REQUIREMENTS_FILE=requiriments/dev.txt
          Se o arquivo requirements.txt estiver na raiz do diretório do projeto, basta informar o nome.
            Exemplo: REQUIREMENTS_FILE=requiriments.txt
        - WORK_DIR=${WORK_DIR} -- deve apontar para o diretório dentro do container onde está o código fonte da aplicação.

    * Variável de nomes de arquivos de configuração do Django:
        - SETTINGS_SAMPLE_LOCAL_FILE=${SETTINGS_SAMPLE_LOCAL_FILE}
        - SETTINGS_LOCAL_FILE=${SETTINGS_LOCAL_FILE}

    * Variável de configuração de banco:
        - DATABASE_NAME=${DATABASE_NAME}
        - DATABASE_USER=${DATABASE_USER}
        - DATABASE_PASSWORD=${DATABASE_PASSWORD}
        - DATABASE_HOST=${DATABASE_HOST}
        - DATABASE_PORT=${DATABASE_PORT}

    * Definições de portas para acesso externo ao containers, acesso à máquina host.
        - APP_PORT=${APP_PORT}
        - PGADMIN_EXTERNAL_PORT=${PGADMIN_EXTERNAL_PORT}
        - REDIS_EXTERNAL_PORT=${REDIS_EXTERNAL_PORT}

    * Definições de imagens
       - DEV_IMAGE=${DEV_IMAGE}
       - PYTHON_BASE_IMAGE=${PYTHON_BASE_IMAGE}
       - POSTGRES_IMAGE=${POSTGRES_IMAGE}

    * Configurações para criação de usuário no container web
       Este usuário isola as modificações dentro do container, evitando que alterações nas permissões dos arquivos
       do projeto afetem da máquina local host.
       - USER_NAME=${USER_NAME}
       - USER_UID=${USER_UID}
       - USER_GID=${USER_GID}

    * Configuração da rede interna
      - VPN_GATEWAY_FAIXA_IP=${VPN_GATEWAY_FAIXA_IP}
      - VPN_GATEWAY=${VPN_GATEWAY}

    * Demais varíaveis:
       - COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
       - GIT_BRANCH_MAIN=${GIT_BRANCH_MAIN}
       - DOCKERFILE=${PROJECT_DOCKERFILE}

    * Variáveis par definição de acesso via VPN. [OPCIONAIS]
        - VPN_WORK_DIR=${VPN_WORK_DIR}  -- diretório onde estão os arquivos do container VPN
        Variáveis utilizadas para adicionar uma rota no container "DB" para o container VPN
          - VPN_GATEWAY=$VPN_GATEWAY
          - ROUTE_NETWORK=<<faixa_enderero_ip>>           -- Exemplo: 10.10.0.0/16
        - DOMAIN_NAME=<<url_dns_banco_externo>>           -- Exemplo: route.domain.local
        - DATABASE_REMOTE_HOST=<<nome_do_banco_externo>>  -- Exemplo: banco_remoto
        Variáveis usadas para adiciona uma nova entrada no arquivo /etc/hosts no container DB,
        permitindo que o sistema resolva nomes de dominío para o endereço IP especificado.
          - ETC_HOSTS=\"
          <<url_dns_host_banco_externo>>:<<ip_host_banco_externo>>
          <<url_dns_host_externo>>:<<ip_host_externo>>
          ...
          \"
          Exemplo:
            ETC_HOSTS=\"
            route.domain.local:10.10.0.144
            \"
  "
  echo_warning "Acima segue as principais variáveis definidas no arquivo \"${PROJECT_ENV_PATH_FILE}\"."
  echo_info "Antes de prosseguir, revise o conteúdo das variáveis apresentadas acima.
  Copie a definição \"REVISADO=1\" e cole no arquivo $ENV_PATH_FILE para está mensagem não mais ser exibida."
  echo "Tecle [ENTER] para continuar"
  read
fi

############ Tratamento para recuperar os arquivos docker-compose ############
function get_compose_command() {
  local dict_services_commands="$1"
  local dict_composes_files="$2"
  local project_dev_dir="$3"
  local script_dir="$4"

  local services=($(dict_keys "${dict_services_commands[*]}"))
  local composes_files=()

  for service in ${services[*]}; do
    local file=$(dict_get "$service" "${dict_composes_files[*]}")
    if [ ! -z "$file" ]; then
      composes_files+=("-f $project_dev_dir/$file")
    fi
  done

  # Retornar o valor de COMPOSE
  COMPOSE="docker compose -f ${script_dir}/docker-compose-base.yml ${composes_files[*]}"
  echo "$COMPOSE"
}

COMPOSE=$(get_compose_command "$DICT_SERVICES_COMMANDS" "$DICT_COMPOSES_FILES" "$PROJECT_DEV_DIR" "$SCRIPT_DIR")
########################## Validações das variávies ##########################
sair=0

# Verificar se a variável COMPOSE_PROJECT_NAME está definida
if [ -z "${COMPOSE_PROJECT_NAME}" ]; then
    echo_error "A variável COMPOSE_PROJECT_NAME não está definida no arquivo \"${PROJECT_ENV_PATH_FILE}\""
    echo_info "Essa variável é usada pelo Docker Compose para definir o nome do projeto.
    O nome do projeto serve como um \"prefixo\" comum para os recursos criados por aquele projeto,
    como redes, volumes, containers e outros objetos Docker."
    echo_info "Sugestão de nome \"COMPOSE_PROJECT_NAME=PROJECT_NAME\". Copie e cole essa definição no arquivo \"${PROJECT_ENV_PATH_FILE}\""
    sair=1
fi

if [ ! -d "$BASE_DIR" ]; then
  echo_error "Diretório base do projeto $BASE_DIR não existe.!"
  echo_info "Defina o nome dele na variável \"BASE_DIR\" em \"${PROJECT_ENV_PATH_FILE}\""
  sair=1
fi

file_requirements_txt="${PROJECT_ROOT_DIR}/${REQUIREMENTS_FILE}"

if [ ! -f "$file_requirements_txt" ]; then
  echo ""
  echo_error "Arquivo $file_requirements_txt não existe.!"
  echo_info "Esse arquivo possui as bibliotecas necessárias para a aplicação funcionar."
  echo_info "Defina o nome dele na variável \"REQUIREMENTS_FILE\" em \"${PROJECT_ENV_PATH_FILE}\""
  sair=1
fi

settings_sample_local_file=$SETTINGS_SAMPLE_LOCAL_FILE
if [ ! -f "$BASE_DIR/$settings_sample_local_file" ]; then
  echo ""
  echo_error "Arquivo $BASE_DIR/$settings_sample_local_file não existe.!"
  echo_info "Esse arquivo é o modelo de configurações mínimas necessárias para a aplicação funcionar."
  echo_info "Defina o nome dele na variável \"SETTINGS_SAMPLE_LOCAL_FILE\" em \"${PROJECT_ENV_PATH_FILE}\""
  sair=1
fi

settings_local_file="${SETTINGS_LOCAL_FILE:-local_settings.py}"
if [ ! -f "$BASE_DIR/$settings_sample_local_file" ]; then
  echo ">>> cp $BASE_DIR/$settings_sample_local_file $BASE_DIR/$settings_local_file"
  cp "$BASE_DIR/$settings_sample_local_file" "$BASE_DIR/$settings_local_file"
  sleep 0.5
fi

if [ ! -f "$BASE_DIR/$settings_local_file" ]; then
  echo ""
  echo_error "Arquivo $BASE_DIR/$settings_local_file não existe.!"
  echo_info "Esse arquivo possui as configurações mínimas necessárias para a aplicação funcionar."
  echo_info "Defina o nome dele na variável \"SETTINGS_LOCAL_FILE\" em \"${PROJECT_ENV_PATH_FILE}\""
  sair=1
fi

if [ $sair -eq 1 ]; then
  echo ""
  echo_error "Impossível continuar!"
  echo_error "Corriga os problemas relatados acima e então execute o comando novamente."
  exit $sair
fi

if [ ! -f "$SCRIPT_DIR/scripts/init_database.sh" ]; then
  echo_warning "Arquivo $SCRIPT_DIR/scripts/init_database.sh não existe. Sem ele, torna-se impossível realizar dump ou restore do banco.!"
  echo_warning "Tecle [ENTER] para continuar."
  read
fi

##############################################################################
### Funções utilitárias para instanciar os serviços
##############################################################################

get_service_names() {
  # Função que retorna um array de nomes de serviços (excluindo "all")
  local _services=($(dict_keys "${DICT_SERVICES_COMMANDS[*]}"))
  local result=()

  for (( idx=${#_services[@]}-1 ; idx>=0 ; idx-- )); do
    local _name_service=${_services[$idx]}
    local _service_name_parse=$(dict_get $_name_service "${DICT_ARG_SERVICE_PARSE[*]}")

    for _parsed_service in ${_service_name_parse[*]}; do
      _name_service=$_parsed_service
    done

    # Adicionar ao array apenas se o nome do serviço não for "all"
    if [ "$_name_service" != "all" ]; then
      result+=("$_name_service")
    fi
  done

  echo "${result[@]}"  # Retorna o array de nomes
}

# Função para verificar se o serviço existe
function check_service_validity() {
  local arg_count=$1
  local services_local=("$2")
  local specific_commands_local=("$3")

  # As variáveis de erro são passadas por referência
  local -n error_danger_message=$4
  local -n error_warning_message=$5

  if ! in_array "$ARG_SERVICE" "${services_local[*]}"; then
    error_danger_message="Serviço [$ARG_SERVICE] não existe."
    error_warning_message="Serviços disponíveis: ${services_local[*]}"
    return 1 # falha - serviço não existe
  else
    return 0 # sucesso - serviço existe
  fi
}

# Função para verificar a validade do comando
function check_command_validity() {
  local arg_count=$1
  local specific_commands_local=("$2")
  local all_commands_local=("$3")
  local service_exists=$4

  # As variáveis de erro são passadas por referência
  local -n error_danger_message=$5
  local -n error_warning_message=$6

  if [ "$service_exists" -eq 0 ] && [ "$arg_count" -ge 2 ]; then
    if ! in_array "$ARG_COMMAND" "${all_commands_local[*]}"; then
      error_danger_message="Comando [$ARG_COMMAND] não existe para o serviço [$ARG_SERVICE]."
      error_warning_message="Comandos disponíveis: \n\t\tcomuns: ${COMMANDS_COMUNS[*]} \n\t\tespecíficos: ${specific_commands_local[*]}"
      return 1 # Falha, comando não é valido
    fi
  fi
  return 0 # Sucesso, comando válido
}

# Função para verificar e validar argumentos
function verify_arguments() {
  local arg_count=$1
  # Copia os argumentos para um array local
  local services_local=("$2")
  local specific_commands_local=("$3")
  local all_commands_local=("$4")

  # As variáveis de erro são passadas por referência
  local -n error_message_danger=$5
  local -n error_message_warning=$6

  # Verifica se o serviço existe
  check_service_validity "$arg_count" "${services_local[*]}" "${specific_commands_local[*]}" error_message_danger error_message_warning
  local _service_ok=$?


  if [ $arg_count -eq 0 ]; then
    error_message_danger="Argumento [NOME_SERVICO] não informado."
    error_message_warning="Serviços disponíveis: ${services_local[@]}"
    return 1
  elif [ $arg_count -eq 1 ]; then
    if [ $_service_ok -eq 0 ]; then # serviço existe
      error_message_danger="Argumento [COMANDOS] não informado."
      error_message_warning="Service $ARG_SERVICE\n\tComandos disponíveis: \n\t\tcomuns: ${COMMANDS_COMUNS[*]} \n\t\tespecíficos: ${specific_commands_local[*]}"
    fi
    return 1 # falha
  elif [ $arg_count -eq 2 ]; then
    # Verifica validade do comando
    check_command_validity "$arg_count" "${specific_commands_local[*]}" "${all_commands_local[*]}" "$_service_ok" error_message_danger error_message_warning
    local _command_ok=$?
    if [ $_command_ok -eq 0 ]; then
      return 0 # sucesso
    fi
    return 1 # falha
  fi
  return 0 #sucesso
}

function imprimir_orientacao_uso() {
  local __usage="
  Usar: $CURRENT_FILE_NAME [NOME_SERVICO] [COMANDOS] [OPCOES]
  Nome do serviço:
    all                         Representa todos os serviços
    web                         Serviço rodando a aplicação SUAP
    db                          Serviço rodando o banco PostgreSQL
    pgadmin                     [Só é iniciado sob demanda]. Deve ser iniciado após o *db* , usar o endereço http://localhost:8001 , usuário **admin@pgadmin.org** , senha **admin** .
    redis                       Serviço rodando o cache Redis
    celery                      [Só é iniciado sob demanda]. Serviço rodando a aplicacão SUAP ativando a fila de tarefa assíncrona gerenciada pelo Celery

  Comandos:

    Comando comuns: Comandos comuns a todos os serciços, exceto **all**
      up                        Sobe o serviço [NOME_SERVICO] em **foreground**
      down                      Para o serviço [NOME_SERVICO]
      restart                   Para e reinicar o serviço [NOME_SERVICO] em **background**
      exec                      Executar um comando usando o serviço [NOME_SERVICO] já subido antes, caso não tenha um container em execução, o comando é executado em em um novo container
      run                       Executa um comando usando a imagem do serviço [NOME_SERVICO] em um **novo** serviço
      logs                      Exibe o log do serviço [NOME_SERVICO]
      shell                     Inicia o shell (bash) do serviço [NOME_SERVICO]

    Comandos específicos:

      all:
        deploy                  Implanta os serviços, deve ser executado no primeiro uso, logo após o
        undeploy                Para tudo e apaga o banco, útil para quando você quer fazer um reset no ambiente
        redeploy                Faz um **undeploy** e um **deploy**
        status                  Lista o status dos serviços
        restart                 Reinicia todos os serviços em ****background***
        logs                    Mostra o log de todos os serviços
        up                      Sobe todos os serviços em **foreground**
        down                    Para todos os serviços

      web:
        build                Constrói a imagem da aplicação web
        makemigrations       Executa o **manage.py makemigrations**
        manage               Executa o **manage.py**
        migrate              Executa o **manage.py migrate**
        shell_plus           Executa o **manage.py shell_plus**
        debug                Inicia um serviço com a capacidade de usar o **breakpoint()** para **debug**

      db:
        psql                 Executa o comando **psql** no serviço
        wait                 Prende o console até que o banco suba, útil para evitar executar **migrate** antes que o banco tenha subido completamente
        dump               Realiza o dump do banco no arquivo $DIR_DUMP/$POSTGRES_DB.sql.gz
        restore              Restaura o banco do arquivo *.sql ou *.gz que esteja no diretório $DIR_DUMP

  Opções: faz uso das opções disponíveis para cada [COMANDOS]

  ˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆˆ
  "
  echo_info "$__usage"
}

# Função para imprimir erros
function print_error_messages() {
  local error_danger_message=$1
  local error_info_message=$2

  if [ ! -z "$error_info_message" ]; then
    imprimir_orientacao_uso
    echo_error "$error_danger_message"
    echo_warning "$error_info_message

    Usar: $CURRENT_FILE_NAME [NOME_SERVICO] [COMANDOS] [OPCOES]
    Role para cima para demais detalhes dos argumentos [NOME_SERVICO] [COMANDOS] [OPCOES]
    "
    exit 1
  fi
}

# Função para processar o comando com base no serviço e argumentos
function process_command() {
  local arg_count=$1
  local service_exists=$2
  _service_name=$(get_server_name "${ARG_SERVICE}")

  if [ "$ARG_COMMAND" = "up" ]; then
    service_up "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "down" ]; then
    service_down "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "restart" ]; then
    service_restart "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "exec" ]; then
    service_exec "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "run" ]; then
    service_run "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "logs" ]; then
    service_logs "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "shell" ]; then
    service_shell "${_service_name}" "$ARG_OPTIONS"

  #for all containers
  elif [ "$ARG_COMMAND" = "status" ]; then
    service_status "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "undeploy" ]; then
    service_undeploy "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "deploy" ]; then
    service_deploy "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "redeploy" ]; then
    service_redeploy "${_service_name}" "$ARG_OPTIONS"

  #for db containers
  elif [ "$ARG_COMMAND" = "psql" ]; then
    command_db_psql "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "restore" ]; then
    database_db_restore "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "dump" ]; then
    database_db_dump "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "copy" ]; then
    database_db_scp "${_service_name}" "$ARG_OPTIONS"

  #for web containers
  elif [ "$ARG_COMMAND" = "build" ]; then
    service_web_build "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "manage" ]; then
    command_web_django_manage "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "makemigrations" ]; then
    command_web_django_manage "${_service_name}" makemigrations "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "migrate" ]; then
    command_web_django_manage  "${_service_name}" "migrate" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "shell_plus" ]; then
    command_web_django_manage "${_service_name}" "shell_plus" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "debug" ]; then
    command_web_django_debug "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "pre-commit" ]; then
    command_pre_commit "${_service_name}" "$ARG_OPTIONS"
  elif [ "$ARG_COMMAND" = "git" ]; then
    command_git "${_service_name}" "$ARG_OPTIONS"
  else
    echo_warning "Comando $ARG_COMMAND sem função associada"
  fi
}

##############################################################################
### FUNÇÕES RESPONSÁVEIS POR INSTACIAR OS SERVIÇOS
##############################################################################
function check_option_d() {
  local _option="$1"

  if [[ $_option =~ "-d" ]]; then
    return 0  # Verdadeiro (True)
  else
    return 1  # Falso (False)
  fi
}

function is_container_running() {
  # usar:
  # if ! is_container_running "$_service_name"; then
  # ...
  # fi
  local _service_name="$1"
  echo ">>> ${FUNCNAME[0]} $_service_name"

  # Verifica se o container está rodando
  if ! $COMPOSE ps | grep -q "${_service_name}.*Up"; then
    echo_warning "O container \"$_service_name\" não está inicializado."
    return 1
  fi
  return 0
}

function container_failed_to_initialize() {
  local exit_code=$?
  local _option="${@:2}"
  local _service_name=$1

  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  declare -a _name_services
  dict_get_and_convert "$_service_name" "${DICT_SERVICES_DEPENDENCIES[*]}" _name_services

  if [ $exit_code -ne 0 ]; then
      # Exibe a mensagem de erro e interrompe a execução do script
      echo_error "Falha ao inicializar o container."

      echo_warning "Parando todos os serviços dependentes de $_service_name que estão em execução ..."
      for _nservice in "${_name_services[@]}"; do
        service_stop "$_nservice" "$_option"
      done
      service_stop "$_service_name" "$_option"
      exit 1 # falha ocorrida
  fi
}

function service_run() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [ "$_service_name" = "$SERVICE_WEB_NAME" ]; then
    echo ">>> $COMPOSE run --rm $_service_name $_option"
    $COMPOSE run --rm "$_service_name" $_option
  else
    echo ">>> $COMPOSE run $_service_name $_option"
    $COMPOSE run "$_service_name" $_option
  fi
}

function service_web_exec() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [ "$(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1)" ]; then
    echo ">>> $COMPOSE exec $_service_name $_option"
    $COMPOSE exec "$_service_name" $_option
  else
    echo_warning "O serviço não está em execução"
  fi
}

function _service_exec() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

#  if [ "$(docker container ls | grep "${COMPOSE_PROJECT_NAME}-${_service_name}-1")" ]; then
  if docker container ls | grep -q "${COMPOSE_PROJECT_NAME}-${_service_name}-1"; then
    if [ "$ARG_SERVICE" = "pgadmin" ]; then
      _option=$(echo "$_option" | sed 's/bash/\/bin\/sh/')
    fi
    echo ">>> $COMPOSE exec $_service_name $_option"
    $COMPOSE exec "$_service_name" $_option
  else
    service_run "$_service_name" $_option
  fi
}

function service_exec() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [ "$ARG_SERVICE" = "$SERVICE_WEB_NAME" ]; then
    service_web_exec "$_service_name" $_option
  else
    _service_exec "$_service_name" $_option
  fi
}

function service_shell() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} "$_service_name" $_option"

  if ! is_container_running "$_service_name"; then
    echo_error "Container $_service_name não está em execução!"
  fi

  if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
    service_exec "$_service_name" bash $_option
  else
    service_run "$_service_name" bash $_option
  fi

  #OCI runtime exec failed: exec failed: container_linux.go:380: starting container process caused: exec: "bash": executable file not found in $PATH: unknown
}

function service_logs() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} "$_service_name" $_option"

  if [ "$_service_name" = "all" ]; then
    echo_info "Status dos serviços"
    $COMPOSE logs -f $_option
  else
    if ! is_container_running "$_service_name"; then
      echo_error "Container $_service_name não está em execução!"
    fi
    $COMPOSE logs -f $_option "$_service_name"
  fi
}

function service_stop() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  # Para o segundo caso com _service_name
  declare -a _name_services
  dict_get_and_convert "$_service_name" "${DICT_SERVICES_DEPENDENCIES[*]}" _name_services

  for _name_service in "${_name_services[@]}"; do
    if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
      echo ">>> docker stop ${COMPOSE_PROJECT_NAME}-${_service_name}-1"
      docker stop ${COMPOSE_PROJECT_NAME}-${_service_name}-1
    fi
  done
    if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
      echo ">>> docker stop ${COMPOSE_PROJECT_NAME}-${_service_name}-1"
      docker stop ${COMPOSE_PROJECT_NAME}-${_service_name}-1
    fi
}

function service_db_wait() {
  local _service_name=$SERVICE_DB_NAME
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"
  echo "--- Aguardando a base de dados ..."

  # Chamar a função para obter o host e a porta correta
  retorno_funcao=1

  # Loop until para continuar tentando até que retorno_funcao seja igual a 1
  until [ $retorno_funcao -eq 0 ]; do
    echo_warning "Tentando conectar ao banco de dados..."

    # Executa o comando dentro do contêiner
    psql_output=$($COMPOSE exec -T $SERVICE_DB_NAME bash -c 'source /scripts/utils.sh && get_host_port "db" "5432" "postgres" "postgres"')
    retorno_funcao=$?

    # Se a função retornar com sucesso (retorno_funcao igual a 1)
    if [ $retorno_funcao -eq 0 ]; then
      # Extrai o host e a porta do output
      read host port <<< "$psql_output"
      echo "host: $host, port: $port"
    fi

    # Pequena pausa antes de tentar novamente (opcional)
    sleep 2
  done


  pg_command="psql -v ON_ERROR_STOP=1 --host=$host --port=$port --username=$POSTGRES_USER"

  echo ">>> sql_output=$($COMPOSE exec -T $SERVICE_DB_NAME bash -c \"PGPASSWORD=$POSTGRES_PASSWORD $pg_command -tc ''SELECT 1;''\" 2>&1)"
  until sql_output=$($COMPOSE exec -T $SERVICE_DB_NAME bash -c "PGPASSWORD=$POSTGRES_PASSWORD $pg_command -tc 'SELECT 1;'" 2>&1); do
    psql_output=$(echo "$psql_output" | xargs)  # remove espaços
    echo_warning "Postgres não disponível - aguardando... "
    echo "Detalhes do erro: $psql_output"
    sleep 2
  done

  echo_success "Postgres está pronto e aceitando conexões."
}

function database_db_scp() {
  local _option="${@:2}"
  local _service_name=$SERVICE_DB_NAME
#  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if ! is_container_running "$_service_name"; then
    echo_info "Inicializando o container db automaticamente ..."
    echo ">>> service_up $_service_name $_option -d"
    service_up $_service_name $_option -d
  fi

  service_db_wait

  echo "$COMPOSE exec $_service_name sh -c \"
    apt-get update > /dev/null && apt-get install -y openssh-client > /dev/null
    scp -i /tmp/dbuser.pem dbuser@$DOMAIN_NAME:/var/opt/backups/$DATABASE_REMOTE_HOST.tar.gz /dump/$DATABASE_REMOTE_HOST.tar.gz
    \""
  $COMPOSE exec $_service_name sh -c "
    apt-get update > /dev/null && apt-get install -y openssh-client > /dev/null
    scp -i /tmp/dbuser.pem dbuser@$DOMAIN_NAME:/var/opt/backups/$DATABASE_REMOTE_HOST.tar.gz /dump/$DATABASE_REMOTE_HOST.tar.gz
    "

}

function database_db_dump() {
  local _option="$@"
  local _service_name=$SERVICE_DB_NAME
  echo ">>> ${FUNCNAME[0]} "$_service_name" $_option"

  echo "--- Realizando o dump do banco $POSTGRES_DB ... "

  _psql="psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

  # Definindo a consulta para pegar o tamanho do banco de dados
  psql_cmd="$_psql -d postgres -tc \"SELECT pg_database_size('$POSTGRES_DB');\""

  # Executando o comando dentro do container Docker para obter o tamanho do banco de dados
  result=$($COMPOSE exec -e PGPASSWORD=$POSTGRES_PASSWORD $_service_name sh -c "$psql_cmd")

  # Verificando se a variável result contém um valor válido
  result=$(echo $result | xargs)  # Remove espaços extras

  # Definir o comando pg_dump com pv e gzip
  pg_dump_cmd="pg_dump -U $POSTGRES_USER -h $POSTGRES_HOST -p $POSTGRES_PORT $POSTGRES_DB | \
  pv -c -s $result -N dump | \
  gzip > /dump/$POSTGRES_DB.sql.gz"

  if is_container_running "$_service_name"; then
    echo ">>> Executando: $COMPOSE exec -e PGPASSWORD=$POSTGRES_PASSWORD $_service_name sh -c \"$pg_dump_cmd\""
    $COMPOSE exec -e PGPASSWORD="$POSTGRES_PASSWORD" $_service_name sh -c "
    apt-get update && apt-get install -y pv gzip &&
    $pg_dump_cmd"
  else
    $COMPOSE run -e PGPASSWORD="$POSTGRES_PASSWORD" $_service_name sh -c "
    apt-get update && apt-get install -y pv gzip &&
    $pg_dump_cmd"
  fi

  echo ">>> service_exec $_service_name chmod 644 /dump/$POSTGRES_DB.sql.gz"
  service_exec "$_service_name" chmod 644 /dump/$POSTGRES_DB.sql.gz

  # Verifica se o código de saída do comando anterior foi executado com falha
  if [ $? -ne 0 ]; then
    echo_warning "Falha ao restaurar dump do banco $POSTGRES_DB"
  else
    echo_info "Backup realizado com sucesso!"
  fi
}

function database_wait() {
  local _service_name=$SERVICE_DB_NAME
  echo ">>> ${FUNCNAME[0]} "$_service_name" $_option"

  service_db_wait

  # Chamar a função para obter o host e a prota correta
  psql_output=$($COMPOSE exec -T $SERVICE_DB_NAME bash -c 'source /scripts/utils.sh && get_host_port "db" "5432" "postgres" "postgres"')
  read host port <<< $psql_output
  if [ $? -gt 0 ]; then
    echo_error "Não foi possível conectar ao banco de dados."
    exit 1
  fi

  local _psql="psql -h $host -p $port -U $POSTGRES_USER -d $POSTGRES_DB"
  echo "$_psql"

  # Definindo o comando psql para verificar a presença de migrações
  local psql_cmd="$_psql -tc 'SELECT COUNT(*) > 0 FROM django_migrations;'"

  echo "--- Aguardando o banco de dados ficar pronto..."
  # Loop até que a consulta retorne verdadeiro (ou seja, 't')
  echo ">>> $COMPOSE exec -e PGPASSWORD=********* $SERVICE_DB_NAME  sh -c  $psql_cmd  | grep -q 't'"
  until $COMPOSE exec -e PGPASSWORD=$POSTGRES_PASSWORD "$SERVICE_DB_NAME" sh -c "$psql_cmd" | grep -q 't'; do
    echo_warning "O banco de dados ainda não está pronto, aguardando... "
    sleep 5  # Aguarda 5 segundos antes de tentar novamente
  done
  echo_success "Banco de dados $POSTGRES_DB está pronto para uso."
}

function database_db_restore() {
  local _service_name=$SERVICE_DB_NAME
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if ! is_container_running "$_service_name"; then
    echo_info "Inicializando o container db automaticamente ..."
    echo ">>> service_up $_service_name $_option -d"
    service_up $_service_name $_option -d
  fi

  service_db_wait

  service_exec "$_service_name" touch /dump/restore.log
  service_exec "$_service_name" chmod 777 /dump/restore.log

  mkdir -p $DIR_DUMP

  local _success=0
  local _retorno_func=0
  echo "--- Iniciando processo de restauração do dump ..."


  service_exec "$_service_name" /docker-entrypoint-initdb.d/init_database.sh

  # Verifica o código de saída do comando anterior foi executado com sucesso
  _retorno_func=$?
  echo "Código de retorno:  $_retorno_func"
  if [ "$_retorno_func" -eq 0 ]; then
    _success=1
    echo_success "A restauração foi realizada com sucesso!"
    echo ""
    echo "Deseja visualizar o arquivo de log gerado? (Digite 's' para sim ou qualquer digite qualquer tecla para finalizar.)"
    read resposta

    if [ "$resposta" = "s" ]; then
      cat "$DIR_DUMP/restore.log"
    fi
  else
    echo_error "Falha ao executar $PROJECT_DEV_DIR/scripts/init_database.sh"
  fi
  return $_success

}

function _service_db_up() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
    echo_warning "O container Postgres já está em execução"
  else
    echo "$COMPOSE up $_option $_service_name"
    $COMPOSE up $_option $_service_name
    container_failed_to_initialize $_service_name $_option
  fi

  if [ "$_service_name" != "db" ] && is_container_running "$_service_name"; then
    service_db_wait
  fi

}

function command_web_django_manage() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  database_wait

  if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
    service_exec "$_service_name" python manage.py $_option
  else
    service_run "$_service_name" python manage.py $_option
  fi
}

function command_web_django_debug() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  database_wait

  $COMPOSE run --rm --service-ports $_service_name python manage.py runserver_plus 0.0.0.0:8000 $_option
}

function command_pre_commit() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
    echo ">>> $COMPOSE exec $_service_name bash -c \"id && git config --global --add safe.directory $WORKDIR && pre-commit run $_option --from-ref origin/master --to-ref HEAD\""
    $COMPOSE exec "$_service_name" bash -c "id && git config --global --add safe.directory $WORKDIR && pre-commit run $_option --from-ref origin/master --to-ref HEAD"
  else
    echo ">>> $COMPOSE run --rm $_service_name \"id && git config --global --add safe.directory $WORKDIR && pre-commit run $_option --from-ref origin/master --to-ref HEAD\""
    $COMPOSE run --rm  "$_service_name" bash -c "id && git config --global --add safe.directory $WORKDIR && pre-commit run $_option --from-ref origin/master --to-ref HEAD"
  fi
}

function command_git() {
  local _service_name="$1"
  shift # Remover o primeiro argumento posicional ($1) -- Remove o nome do serviço da lista de argumentos
  local _option="$@"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  command_pre_commit "$service_name" "$_option"

  if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
    echo ">>> $COMPOSE exec $_service_name git $_option"
    $COMPOSE exec "$_service_name" git "$_option"
  else
    echo ">>> $COMPOSE run $_service_name git $_option"
    $COMPOSE runt "$_service_name" git "$_option"
  fi
}

function _service_web_up() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  database_wait

  echo ">>> $COMPOSE up $_option $_service_name"
  $COMPOSE up $_option $_service_name
  container_failed_to_initialize $_service_name $_option
}

function _service_all_up() {
  local _option="${@:1}"
  echo ">>> ${FUNCNAME[0]} $_option"

  # Chama a função e captura o array retornado
  service_names=($(get_service_names))

  # Itera sobre o array retornado pela função
  for _name_service in "${service_names[@]}"; do
    _service_up $_name_service -d $_option
  done
}

function _service_up() {
  local _option="${@:2}"
  local _service_name="$1"
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [ $_service_name = "all" ]; then
    _service_all_up $_option
#    $COMPOSE up $_option
  elif [ $_service_name = "db" ]; then
    _service_db_up $_service_name $_option
  elif [ $_service_name = $SERVICE_WEB_NAME ]; then
    _service_web_up $_service_name $_option
  else
    local _nservice=$(get_server_name ${_service_name})
    echo ">>> $COMPOSE up $_option $_nservice"
    $COMPOSE up $_option $_nservice
    container_failed_to_initialize $_service_name $_option
  fi
}

function service_up() {
  local _option="${@:2}"
  local _service_name=$1
#  local _name_services=($(string_to_array $(dict_get "$ARG_SERVICE" "${DICT_SERVICES_DEPENDENCIES[*]}")))

  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  declare -a _name_services
  dict_get_and_convert "$ARG_SERVICE" "${DICT_SERVICES_DEPENDENCIES[*]}" _name_services

  for _nservice in "${_name_services[@]}"; do
    _service_up $_nservice -d
  done
  _service_up $_service_name $_option
}

function _service_down() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  if [ $_service_name = "all" ]; then
    echo ">>> $COMPOSE down --remove-orphans $_option"
    $COMPOSE down --remove-orphans $_option
  else
    if [[ $(docker container ls | grep ${COMPOSE_PROJECT_NAME}-${_service_name}-1) ]]; then
      echo ">>> docker stop ${COMPOSE_PROJECT_NAME}-${_service_name}-1"
      docker stop ${COMPOSE_PROJECT_NAME}-${_service_name}-1

      echo ">>> docker rm ${COMPOSE_PROJECT_NAME}-${_service_name}-1"
      docker rm ${COMPOSE_PROJECT_NAME}-${_service_name}-1
    else
      echo ">>> $COMPOSE down ${_service_name} $_option"
      $COMPOSE down ${_service_name} $_option
    fi
  fi
}

function service_down() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  declare -a _name_services
  dict_get_and_convert "$_service_name" "${DICT_SERVICES_DEPENDENCIES[*]}" _name_services

  for _name_service in "${_name_services[@]}"; do
    _service_down $_name_service $_option
  done
  _service_down $_service_name $_option
}

function service_restart() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  #  if [ $_service_name = "all" ]; then
  service_down $_service_name $_option
  service_up $_service_name -d $_option
  #  else
  #    service_down $_service_name $_option
  #    service_up $_service_name -d $_option
  #  fi

}

function service_web_build() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  echo ">>> $COMPOSE build --no-cache $SERVICE_WEB_NAME $_option"
  $COMPOSE build --no-cache $SERVICE_WEB_NAME $_option
  container_failed_to_initialize $_service_name $_option

  service_up $SERVICE_WEB_NAME $_option
}

function service_deploy() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"
  service_down $_service_name -v $_option
  service_web_build $SERVICE_WEB_NAME $_option
}

function service_redeploy() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"
  service_undeploy
  service_deploy
}

function service_undeploy() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"
  # Opção -v remove todos os volumens atachado
  service_down $_service_name -v $_option

  rm -rf docker/volumes
}

function service_status() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  echo ">>> $COMPOSE ps -a"
  $COMPOSE ps -a
}

function command_db_psql() {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  service_db_wait

  echo ">>> service_exec $_service_name psql -U $POSTGRES_USER $_option"
  service_exec "$_service_name" psql -U $POSTGRES_USER $_option
  #-d $POSTGRES_DB $@
}

##############################################################################
### Tratamento para Ctrl+C
##############################################################################

# Função que será chamada quando o script for interrompido
function handle_sigint {
  local _option="${@:2}"
  local _service_name=$1
  echo ">>> ${FUNCNAME[0]} $_service_name $_option"

  echo "Interrompido com Ctrl+C. "
  if [ $ARG_COMMAND = "up" ]; then
   service_stop "${_service_name}" "$ARG_OPTIONS"
  fi
  exit 1
}

# Configura o trap para capturar o sinal SIGINT (Ctrl+C)
trap handle_sigint SIGINT

##############################################################################
### TRATAMENTO PARA VALIDAR OS ARGUMENTOS PASSADOS
##############################################################################
# Função principal que orquestra a execução
function main() {
#  set -x  # Ativa o modo de depuração para verificar a execução
  local arg_count=$#
  declare -a specific_commands_local
  dict_get_and_convert "$ARG_SERVICE" "${DICT_SERVICES_COMMANDS[*]}" specific_commands_local

  local services_local=($(dict_keys "${DICT_SERVICES_COMMANDS[*]}"))
  local all_commands_local=("${specific_commands_local[@]}")
  all_commands_local+=("${COMMANDS_COMUNS[@]}")

  create_pre_push_hook "$COMPOSE" "$SERVICE_WEB_NAME" "$WORK_DIR" "$GIT_BRANCH_MAIN"

  error_danger=""
  error_warning=""

  verify_arguments "$arg_count"  "${services_local[*]}"  "${specific_commands_local[*]}" "${all_commands_local[*]}" error_danger error_warning
  argumento_valido=$?

  # Verifica o código de saída da função
  if [ $argumento_valido -ne 1 ]; then
    # Processa os comandos recebidos
    process_command "$arg_count" "$service_exists"
  else
    print_error_messages "$error_danger" "$error_warning"
  fi
  exit 1

}

# Chama a função principal
main "$@"
