#!/bin/bash

# Begin Standard 'imports'
set -e
set -o pipefail


gray="\\e[37m"
blue="\\e[36m"
red="\\e[31m"
green="\\e[32m"
yellow="\\e[33m"
reset="\\e[0m"

info() { echo -e "${blue}INFO: $*${reset}"; }

error() { echo -e "${red}ERROR: $*${reset}"; }

debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    echo -e "${gray}DEBUG: $*${reset}";
  fi
}

warning() { echo -e "${yellow}✔ $*${reset}"; }

success() { echo -e "${green}✔ $*${reset}"; }

fail() { echo -e "${red}✖ $*${reset}"; exit 1; }

## Enable debug mode.
enable_debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    info "Enabling debug mode."
    set -x
  fi
}

docker_build_and_push() {
  export IMAGE_NAME=$BITBUCKET_REPO_SLUG:${BITBUCKET_COMMIT::7}
  echo ${GCLOUD_API_KEYFILE} > ~/.gcloud-api-key.json

  docker login -u _json_key -p "$(cat ~/.gcloud-api-key.json)" https://us-east1-docker.pkg.dev
  docker images
  docker build . -t $GCLOUD_REGISTRY/${IMAGE_NAME}
  docker images
  docker tag $GCLOUD_REGISTRY/${IMAGE_NAME}
  docker push $GCLOUD_REGISTRY/${IMAGE_NAME}
}


internal_publish() {
  export IMAGE_NAME=$BITBUCKET_REPO_SLUG:$BITBUCKET_COMMIT
  export CI_PROJECT_NAME=${BITBUCKET_REPO_SLUG}
  export IMAGE_VERSION=${BITBUCKET_COMMIT::7}
    
  rm -rf ./deploy
  mkdir -p ./deploy

  for f in $(find k8s/$BITBUCKET_BRANCH  -regex '.*\.ya*ml'); do envsubst < $f > "./deploy/$(basename $f)" && sed -i '/^ *$/d' "./deploy/$(basename $f)"; done

  ARCTIFACT_NAME=${BITBUCKET_REPO_SLUG}-${BITBUCKET_COMMIT}.tar.gz
  tar -zcvf ${ARCTIFACT_NAME} ./deploy

  for f in $(find ./deploy  -regex '.*\.ya*ml'); do cat $f >> deployment.yaml && echo  -e "\n---\n" >> deployment.yaml; done

  cat deployment.yaml

  kubectl apply -R -f deployment.yaml  --record

  curl -v --upload-file ${ARCTIFACT_NAME} -H "Authorization: Bearer `gcloud auth print-access-token`" "https://storage.googleapis.com/cicd-bitbucket-pipelines/${BITBUCKET_REPO_SLUG}-${BITBUCKET_COMMIT}.tar.gz"

  #BITBUCKET_USERNAME=mgamarra.ext@mtrix.com.br
  #BITBUCKET_APP_PASSWORD=@34NovaSenha562201
  #curl -X POST "https://${BITBUCKET_USERNAME}:${BITBUCKET_APP_PASSWORD}@api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}/downloads" --form files=@"${ARCTIFACT_NAME}"  
}

okd_publish() {
  oc login --insecure-skip-tls-verify ${OC_DESEN_URL} -u ${OC_DESEN_USERNAME} -p ${OC_DESEN_PASSWORD}
  internal_publish
}    

gke_publish() {
  echo ${GCLOUD_API_KEYFILE} > gcloud-api-key.json
  echo ${GCLOUD_API_KEYFILE} 

  gke-gcloud-auth-plugin --version
  getent passwd $USER | awk -F ':' '{print $6}'
  gcloud auth login --cred-file=gcloud-api-key.json 
  gcloud container clusters get-credentials $GCLOUD_K8S_CLUSTER_NAME --zone=$GCLOUD_K8S_ZONE --project $GCLOUD_K8S_PROJECT_ID      
  internal_publish
}    



### CHAMADAS EXTERNAS - Argumentos do script -----------------------------------------------#
main () {
  case $1 in
    "docker_build_and_push")
      docker_build_and_push "$@"
      ;;
    "okd_publish")
      okd_publish "$@"
      ;;      
    "gke_publish")
      gke_publish "$@"
      ;;
    "version")
      echo "pgnci-$app_semver $2"
      exit 0
      ;;
    *)
      echo "Erro: argumento inválido"
      exit 1
      ;;
  esac
}
### ----------------------------------------------------------------------------------------#

# Chamada para possibilitar testes. Só entra na main se não for via source
if [[ "${#BASH_SOURCE[@]}" -eq 1 ]]; then
    echo "$@" 
  main "$@"
fi
