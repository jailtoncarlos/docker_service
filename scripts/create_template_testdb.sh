#!/bin/bash

UTILS_SH="utils.sh"
if [ -n "$PG_VERSION" ]; then
  echo "Executando via docker-compose"
  UTILS_SH="/scripts/utils.sh"
fi
# shellcheck disable=SC1090
source "$UTILS_SH"

function create_template_testdb() {
    local postgres_host="$1"
    local postgres_port="$2"
    local postgres_user="$3"
    local postgres_db="$4"
    local postgres_password="$5"
    local template_testdb="$6"

    local file_sql_db_structure
    local pg_command

    echo ">>> ${FUNCNAME[0]} $postgres_host $postgres_port $postgres_db $postgres_user <<paswword>>"

    export PGPASSWORD=$postgres_password

    file_sql_db_structure="db_structure.sql"
    pg_command="psql -v ON_ERROR_STOP=1 --host=${postgres_host} --port=${postgres_port} --username=${postgres_user} --dbname=${postgres_db}"

    echo "--- Fazendo dump do esquema do banco $postgres_db para o arquivo $file_sql_db_structure ..."
    echo ">>> pg_dump --schema-only --host=${postgres_host} --port=${postgres_port} --username=${postgres_user} --dbname=${postgres_db} > $file_sql_db_structure"

    pg_dump --schema-only --host="${postgres_host}" --port="${postgres_port}" --username="${postgres_user}" --dbname="${postgres_db}" > "$file_sql_db_structure"
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "Falha ao fazer o dump."
        return 1
    fi

    echo "--- Recriando o database template $template_testdb ..."
    $pg_command  <<-EOSQL
        UPDATE pg_database SET datistemplate = FALSE WHERE datname = '$template_testdb';
        DROP DATABASE IF EXISTS "$template_testdb";
        CREATE DATABASE "$template_testdb";
        GRANT ALL PRIVILEGES ON DATABASE "$template_testdb" TO "$postgres_user";
EOSQL

    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "Falha ao recriar o banco."
        return 1
    fi

    echo "--- Restaurando o dump do arquivo $file_sql_db_structure para o banco $template_testdb ..."
    echo "Logs disponíveis no arquivo /dump/restore.log"
    echo ">>> $pg_command -d $template_testdb < $file_sql_db_structure 2>&1 | tee /dump/restore.log"

    $pg_command -d "$template_testdb" < "$file_sql_db_structure" 2>&1 | tee /dump/restore.log
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "Falha ao restaurar o dump."
        return 1
    fi

    echo "--- Definindo o banco $template_testdb como template ..."
    echo ">>> $pg_command -t -c \"UPDATE pg_database SET datistemplate = TRUE WHERE datname = '$template_testdb';\""

    $pg_command -t -c "UPDATE pg_database SET datistemplate = TRUE WHERE datname = '$template_testdb';"
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "Falha ao definir o banco como template."
        return 1
    fi

    # Verifica se o template foi criado com sucesso
    echo "--- Verificando se o template $template_testdb foi criado com sucesso..."
    check_template_testdb_exists "$postgres_host" "$postgres_port" "$postgres_user" "$postgres_db" "$postgres_password" "$template_testdb"
    if [ $? -eq 0 ]; then
        echo "Database template \"$template_testdb\" criado com sucesso!"
        return 0
    else
        echo "Falha ao criar o database template \"$template_testdb\"."
        return 1
    fi
}

function check_template_testdb_exists() {
    local postgres_host="$1"
    local postgres_port="$2"
    local postgres_user="$3"
    local postgres_db="$4"
    local postgres_password="$5"
    local template_testdb="$6"

    # Configura a senha do PostgreSQL
    export PGPASSWORD=$postgres_password

    # Comando para acessar o banco de dados
    local pg_command="psql --host=${postgres_host} --port=${postgres_port} --username=${postgres_user} --dbname=${postgres_db} --tuples-only --no-align"

    # Verifica se o template existe
    echo "Verificando se o template $template_testdb existe..."
    template_exists=$($pg_command -c "SELECT 1 FROM pg_database WHERE datname = '$template_testdb' AND datistemplate = TRUE;")

    if [ "$template_exists" == "1" ]; then
        echo "O template $template_testdb existe."
        return 0
    else
        echo "O template $template_testdb não foi encontrado."
        return 1
    fi
}
