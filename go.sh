#!/bin/bash
# SHIB_FILE_PATH="apache-shib/files/shib-keys"

if [[ ! -f .env ]]; then
  echo "No .env found.  Copy .env.dist to .env and update parameters"
  exit 1
fi

source .env

SHIB_FILE_PATH="shibboleth-sp3/files/shib-keys"
NODE_CERT_FILE_PATH="node-app/certs"
if [[ $1 == "reset-certs" ]]; then
  rm nginx-shib/certs/*
  rm shibboleth-sp3/files/shib-keys/*
  rm node-app/certs/*

elif [[ $1 == "init" ]]; then
  mkdir -p $SHIB_FILE_PATH

  if [[ ! -f "${SHIB_FILE_PATH}/sp.encrypt.cert.pem" ]]; then 
    # I don't want to rely on shib-keygen being installed, so we'll use docker since we're already in for docker.
    docker run --rm -it -v $PWD/$SHIB_FILE_PATH:/data/:rw -e  DEBIAN_FRONTEND="noninteractive" -e TZ="America/New_York" ubuntu bash -c "\
      apt-get update && \
      apt-get install -y shibboleth-sp2-utils && \
      cd /data && \
      shib-keygen -n sp-signing -f -h $Domain_Name -y 10 -o \$PWD && \
      shib-keygen -n sp-encrypt -f -h $Domain_Name -y 10 -o \$PWD"
    # Shib-keygen doesn't let you change the `-cert` and `-key` suffix.  move files because I'd like them to match secrets-entrypoint convention
    mv $SHIB_FILE_PATH/sp-signing-cert.pem $SHIB_FILE_PATH/sp.signing.cert.pem
    mv $SHIB_FILE_PATH/sp-signing-key.pem $SHIB_FILE_PATH/sp.signing.key.pem

    mv $SHIB_FILE_PATH/sp-encrypt-cert.pem $SHIB_FILE_PATH/sp.encrypt.cert.pem
    mv $SHIB_FILE_PATH/sp-encrypt-key.pem $SHIB_FILE_PATH/sp.encrypt.key.pem
  fi

# This is a useful step if your app should actually do something.
# if [[ ! -f "app/config/config.inc.php" ]]; then
#   echo "WARN: config.inc.php not found; copying placeholder.  Please edit before running"
#   cp app/config/config.sample.inc.php app/config/config.inc.php
# fi
  if [[ ! -f "nginx-shib/certs/keyfile.crt" ]]; then
    cd nginx-shib/
    ./genSelfSignedCerts.sh $Domain_Name
    cd -
  fi

  if [[ ! -f "${NODE_CERT_FILE_PATH}/keyfile.crt" ]]; then
  mkdir -p $NODE_CERT_FILE_PATH
    cd ${NODE_CERT_FILE_PATH}/..
    ../nginx-shib/genSelfSignedCerts.sh $Domain_Name
    cd -
  fi
  echo "Done"

elif [[ $1 == "build" ]]; then
  docker-compose build

elif [[ $1 == "run" ]]; then 
  shift
  docker-compose up $@

elif [[ $1 == "logs" ]]; then 
  shift
  docker-compose logs $@

elif [[ $1 == "reset" ]]; then 
  docker-compose stop
  docker-compose rm -f


# https://www.matteomattei.com/client-and-server-ssl-mutual-authentication-with-nodejs/
elif [[ $1 == "tls" ]]; then 
  set -x
  mkdir tmp/certs -p
  cd tmp/certs
  openssl req -new -x509 -days 365 -keyout server-ca-key.pem -out server-ca-crt.pem -nodes \
    -subj "/O=Cornell University - Dev/L=Ithaca/ST=NY/C=US/CN=ca.dev.local"

  openssl genrsa -out server-key.pem 4096

  openssl req -new -sha256 -key server-key.pem -out server-csr.pem -nodes \
    -subj "/O=Cornell University - Dev/L=Ithaca/ST=NY/C=US/CN=dev.local"
  openssl x509 -req -days 365 -in server-csr.pem -CA server-ca-crt.pem -CAkey server-ca-key.pem -CAcreateserial -out server-crt.pem
  openssl verify -CAfile server-ca-crt.pem server-crt.pem

  # CLIENT
  openssl req -new -x509 -days 365 -keyout client-ca-key.pem -out client-ca-crt.pem -nodes \
    -subj "/O=Cornell University - Dev/L=Ithaca/ST=NY/C=US/CN=ca.dev.local"

  openssl genrsa -out client-key.pem 4096

  openssl req -new -sha256 -key client-key.pem -out client-csr.pem -nodes \
    -subj "/O=Cornell University - Dev/L=Ithaca/ST=NY/C=US/CN=dev.local"
  openssl x509 -req -days 365 -in client-csr.pem -CA client-ca-crt.pem -CAkey client-ca-key.pem -CAcreateserial -out client-crt.pem
  openssl verify -CAfile client-ca-crt.pem client-crt.pem

  cp client-ca-crt.pem ../../node-app/certs/
  cp client-key.pem ../../nginx-shib/certs
  cp client-crt.pem ../../nginx-shib/certs

  cp server-ca-crt.pem ../../nginx-shib/certs/
  cp server-key.pem ../../node-app/certs
  cp server-crt.pem ../../node-app/certs




else
    echo "options: init, build, run, reset, reset-certs, clean"
fi

# Above command should generate these files
# sp-encrypt-cert.pem
# sp-encrypt-key.pem
# sp-signing-cert.pem
# sp-signing-key.pem
# https://superuser.com/questions/226192/avoid-password-prompt-for-keys-and-prompts-for-dn-information
