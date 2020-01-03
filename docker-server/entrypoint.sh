#!/bin/bash

MODEL_URL=${MODEL_URL:?"MODEL_URL must be defined"}
IS_IN_DCOS=${IS_IN_DCOS:-"false"}
MODEL_DOWNLOADED_LOCATION="/tmp/model.zip"
curl_cmd=""

if [ ${IS_IN_DCOS} = "true" ]; then
  # ---------------------------------------------------------------------------------------------------------------------
  # => Vault integration
  # ---------------------------------------------------------------------------------------------------------------------

  # => Executing kms_utils script -> loads some utility functions to accessing vault secrets
  echo "=> Using kms_utils script to download instance secrets:"

  source /kms_utils.sh
      #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #@@@@    Note: this library expects the following vars as globals        @@@@@@@
      #@@@@        - VAULT_HOSTS [array]                                       @@@@@@@
      #@@@@        - VAULT_PORT  [int]                                         @@@@@@@
      #@@@@        - VAULT_ROLE_ID [string]                                    @@@@@@@
      #@@@@        - VAULT_SECRET_ID [string]                                  @@@@@@@
      #@@@@        - [optional] VAULT_TOKEN [string]                           @@@@@@@
      #@@@@                                                                    @@@@@@@
      #@@@@      To read an array from comma separted string                   @@@@@@@
      #@@@@          IFS=',' read -r -a VAULT_HOSTS <<< "$STRING_VAULT_HOST"   @@@@@@@
      #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


  # · VAULT_HOSTS: To read an array from comma separated string -> defined in  VAULT_HOST env.var
  declare -a VAULT_HOSTS
  IFS=',' read -r -a VAULT_HOSTS <<< "$VAULT_HOST"


  # Check dynamic authetication
  if [ "$USE_DYNAMIC_AUTHENTICATION" = "true" ]; then
      echo "· Using dynamic authentication. Login in vault..."; echo -e "\n"
      login
  fi

  ########### Certificates management ################

  # Extract client auth property for the TLS management [need | want]
  export CLIENT_AUTH_PROPERTY=${CLIENT_AUTH_PROPERTY:-"want"}

  # => Getting TLS certificates and CA bundle
  # Extract the default keystore password in $<generic_instance_name>_KEYSTORE_PASS
  echo "=> Downloading keystore password..."

  securityPath=/opt/sds/mleap-microservice/security
  mkdir -p $securityPath

  export GENERIC_INSTANCE_NAME=${GENERIC_INSTANCE_NAME:-"microservicemleap"}
  export VAULT_JSON_CERT_KEY=${VAULT_JSON_CERT_KEY:-"microservicemleap"}
  export VAULT_SECRET_CLUSTER=${VAULT_SECRET_CLUSTER:-"userland"}

  getPass ${VAULT_SECRET_CLUSTER} ${GENERIC_INSTANCE_NAME} keystore
  result="$?"

  uppercase_generic_instance_name=$(echo $GENERIC_INSTANCE_NAME | tr '[:lower:]' '[:upper:]')
  normalized_generic_instance_name=${uppercase_generic_instance_name//[.-]/_}

  pass_env_var="${normalized_generic_instance_name}_KEYSTORE_PASS"
  export KEYSTORE_PASS="${!pass_env_var}"
  if [ $result -ne 0 ] || [ -z "${KEYSTORE_PASS}" ]; then
      echo "ERROR. keystore password wasn't retrieved from Vault"
      exit 1
  fi

  echo "... keystore password correctly retrieved. "

  # Let's download the JKS certificate
  echo "=> Getting generic SSL JKS certificate ..."

  export KEYSTORE_PATH=$securityPath/$VAULT_JSON_CERT_KEY.jks
  getCert ${VAULT_SECRET_CLUSTER}  ${GENERIC_INSTANCE_NAME} ${VAULT_JSON_CERT_KEY} JKS $securityPath
  result="$?"

  if [ $result -ne 0 ] || [ ! -f "$KEYSTORE_PATH" ]; then
      echo "ERROR. SSL Certificate wasn't retrieved from Vault"
      exit 1
  fi
  echo "... SSL certificate correctly retrieved"

  echo "=> Getting generic SSL PEM certificate ..."

  SSL_KEY_UNFOLDED="/tmp/$VAULT_JSON_CERT_KEY.key"
  SSL_CERT_UNFOLDED="/tmp/$VAULT_JSON_CERT_KEY.pem"
  getCert ${VAULT_SECRET_CLUSTER} $GENERIC_INSTANCE_NAME $VAULT_JSON_CERT_KEY PEM /tmp
  result="$?"

  if [ $result -ne 0 ] || [ ! -f "$SSL_KEY_UNFOLDED" ] || [ ! -f "$SSL_CERT_UNFOLDED" ]; then
      echo "ERROR. PEM Certificates weren't retrieved from Vault"
      exit 1
  fi


  ########### CA Bundle management ################
  # Getting the CA bundle
  echo "=> Getting CA bundle ..."

  export CA_PATH=$securityPath/ca-bundle.jks
  getCAbundle $securityPath JKS
  result="$?"

  if [ $result -ne 0 ] || [ ! -f "$CA_PATH" ]; then
      echo "ERROR. CA bundle wasn't retrieved from Vault"
      exit 1
  fi

  export $DEFAULT_KEYSTORE_PASS
  echo "... CA bundle correclty retrieved"

  # Pem format download
  echo "=> Getting PEM CA bundle ..."

  SSL_CA_UNFOLDED=/tmp/ca-bundle.pem
  getCAbundle /tmp PEM
  result="$?"

  if [ $result -ne 0 ] || [ ! -f "$SSL_CA_UNFOLDED" ]; then
      echo "ERROR. PEM CA bundle wasn't retrieved from Vault"
      exit 1
  fi

  ## Normalize pem certificates to 64 chars per line, otherwise curl will not work
  export SSL_KEY=$securityPath/$VAULT_JSON_CERT_KEY.key
  export SSL_CERT=$securityPath/$VAULT_JSON_CERT_KEY.pem
  export SSL_CA=$securityPath/ca-bundle.pem
  fold -w 64 $SSL_KEY_UNFOLDED > $SSL_KEY
  fold -w 64 $SSL_CERT_UNFOLDED > $SSL_CERT
  fold -w 64 $SSL_CA_UNFOLDED > $SSL_CA

  # delete unfolded certs
  rm $SSL_KEY_UNFOLDED
  rm $SSL_CERT_UNFOLDED
  rm $SSL_CA_UNFOLDED

  # curl -f -> fail silenlty: no failure output
  # curl -L -> follow redirect
  # curl -s -> quite mode. Don't show progress meter or error messages

  curl_cmd="curl -fLs  -o ${MODEL_DOWNLOADED_LOCATION} -w %{response_code} --cacert ${SSL_CA} --cert ${SSL_CERT} --key ${SSL_KEY} ${MODEL_URL}"

else
  curl_cmd="curl -fLsk -o ${MODEL_DOWNLOADED_LOCATION} -w %{response_code} ${MODEL_URL}"
fi

########### Downloading model ################

echo "=> Downloading serialized model ..."
echo " · curl_cmd: ${curl_cmd}"
status_code=$(${curl_cmd})
# Checking if model.zip file has been correctly downloaded
if [ ! "${status_code}" = "200" ]; then
    echo "request for download model.zip from ${MODEL_URL} has returned ${status_code}"
    exit 1
elif [ ! -f /tmp/model.zip ]; then
    echo "model.zip file has not been correctly downloaded but response status code is: ${status_code}"
    exit 1
fi

echo "... model.zip has been correctly downloaded."

########### unziping model ####################

MODELS_PATH="/models"
mkdir ${MODELS_PATH}

echo "=> unziping model ..."
unzip ${MODEL_DOWNLOADED_LOCATION} -d ${MODELS_PATH}


mlflow models serve -m ${MODELS_PATH} -p ${PORT:-1234} -h "0.0.0.0"