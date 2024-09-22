#!/bin/bash

#Explicação do Funcionamento:
#Parâmetros:
#
#file: O arquivo .ini que será lido.
#section: A seção do arquivo .ini onde se encontra a chave.
#key: A chave dentro da seção que será lida.
#Como funciona:
#
#O comando sed é usado para procurar a seção correta (^\[$section\]).
#Dentro dessa seção, ele continua procurando a chave (^$key[ ]*=).
#Quando a chave é encontrada, o valor é extraído removendo o conteúdo antes do = e exibindo o que vem após o símbolo.
#Detalhes Técnicos:
#
#O sed -nr utiliza a opção -n para não imprimir todas as linhas por padrão, e -r para permitir o uso de expressões regulares extendidas.
#O rótulo :l e o comando b l criam um loop para continuar analisando a linha até encontrar a chave desejada.
#Quando a chave é encontrada, s/.*=[ ]*// remove tudo até o = e p imprime o valor.

# Function to read a value from an ini file
function read_ini() {
    local file=$1
    local section=$2
    local key=$3

    # Extract the value using grep and sed
    value=$(sed -nr "/^\[$section\]/ { :l /^$key[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" $file)
    echo $value
}

# Example usage
#user=$(read_ini "config.ini" "database" "user")
#echo "User: $user"
