#!/bin/bash

# Begin Standard 'imports'
set -x
#set -e
#set -o pipefail

app_semver="0.2.1"

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

code_analisys() {
  warning "Not implemented"
}

docker_build_and_push() {
  export IMAGE_NAME=$BITBUCKET_REPO_SLUG:${BITBUCKET_COMMIT::7}
  echo "${GCLOUD_API_KEYFILE}" > ~/.gcloud-api-key.json

  docker login -u _json_key -p "$(cat ~/.gcloud-api-key.json)" ${GCLOUD_REGISTRY}
  docker images
  #docker build  . -t "$GCLOUD_REGISTRY"/"${IMAGE_NAME}"
  docker build -f Dockerfile -t "$GCLOUD_REGISTRY"/"${IMAGE_NAME}" $(for i in `env`; do out+="--build-arg $i " ; done; echo $out;) .
  #docker build --network host . -t $GCLOUD_REGISTRY/${IMAGE_NAME}
  #docker build --network host -f Dockerfile  -t $GCLOUD_REGISTRY/${IMAGE_NAME} .
  docker images
  #docker tag $GCLOUD_REGISTRY/${IMAGE_NAME}
  docker push "$GCLOUD_REGISTRY"/"${IMAGE_NAME}"
}


internal_publish() {
  export IMAGE_NAME=$BITBUCKET_REPO_SLUG:$BITBUCKET_COMMIT
  export CI_PROJECT_NAME=${BITBUCKET_REPO_SLUG}
  export IMAGE_VERSION=${BITBUCKET_COMMIT::7}
    
  rm -rf ./deploy
  mkdir -p ./deploy

  if [ $BITBUCKET_BRANCH == 'master' ]; then 
    sed -i 's/\${CI_PROJECT_NAME}-\${INGRESS_SUFIX}/\${CI_PROJECT_NAME}.\${INGRESS_SUFIX}/g' k8s/apisix-ingress.yaml
  fi

  for f in $(find k8s -maxdepth 1  -regex '.*\.ya*ml'); do envsubst < $f > "./deploy/$(basename $f)" && sed -i '/^ *$/d' "./deploy/${f//[\/]/-}"; done

  for f in $(find k8s/$BITBUCKET_BRANCH  -regex '.*\.ya*ml'); do envsubst < $f > "./deploy/$(basename $f)" && sed -i '/^ *$/d' "./deploy/$(basename $f)"; done

  ls -lha ./deploy/
  
  ARCTIFACT_NAME=${BITBUCKET_REPO_SLUG}-${BITBUCKET_COMMIT}.tar.gz
  tar -zcvf ${ARCTIFACT_NAME} ./deploy

  for f in $(find ./deploy  -regex '.*\.ya*ml'); do echo  -e "\n---\n# $f\n---\n" >> deployment.yaml && cat "$f" >> deployment.yaml  ; done
 
  cat deployment.yaml

  #warning "kubectl get namespace | grep -q "^$K8S_NAMESPACE " | kubectl create namespace $K8S_NAMESPACE

  NS_EXISTS=$(kubectl get namespace | grep -q "^$K8S_NAMESPACE ")

  if [ -z "$NS_EXISTS" ]; then
    kubectl create namespace "$K8S_NAMESPACE"
  fi

  #kubectl get namespace | grep -q "^$K8S_NAMESPACE " | kubectl create namespace $K8S_NAMESPACE

  kubectl apply -R -f deployment.yaml  --record

 # curl -v --upload-file ${ARCTIFACT_NAME} -H "Authorization: Bearer `gcloud auth print-access-token`" "https://storage.googleapis.com/cicd-bitbucket-pipelines/${BITBUCKET_REPO_SLUG}-${BITBUCKET_COMMIT}.tar.gz"

  echo "*****************"
  kubectl get ingress -n "$K8S_NAMESPACE" 
  echo "*****************  URL NGIX"
  kubectl get ingress -n "$K8S_NAMESPACE" | grep "$CI_PROJECT_NAME"
  echo "***************** URL APISIX"
  
  kubectl get ApisixRoute -n "$K8S_NAMESPACE" | grep "$CI_PROJECT_NAME"
  echo "*****************"

  #BITBUCKET_USERNAME=mgamarra.ext@mtrix.com.br
  #BITBUCKET_APP_PASSWORD=@34NovaSenha562201
  #curl -X POST "https://${BITBUCKET_USERNAME}:${BITBUCKET_APP_PASSWORD}@api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}/downloads" --form files=@"${ARCTIFACT_NAME}"  
}

okd_publish() {
  oc login --insecure-skip-tls-verify" ${OC_DESEN_URL}" -u "${OC_DESEN_USERNAME}" -p "${OC_DESEN_PASSWORD}"
  internal_publish
}    

gke_publish() {
  #echo "${GCLOUD_API_KEYFILE}" > gcloud-api-key.json
  #echo "${GCLOUD_API_KEYFILE}" 
  #gcloud auth login --cred-file=gcloud-api-key.json 

  gke-gcloud-auth-plugin --version
  getent passwd "$USER" | awk -F ':' '{print $6}'
  gcloud container clusters get-credentials "$GCLOUD_K8S_CLUSTER_NAME" --region="$GCLOUD_K8S_REGION" --project "$GCLOUD_K8S_PROJECT_ID"    
  #gcloud container clusters get-credentials core-development --region us-central1 --project prj-dev-d-base-f34c 

  internal_publish
}    



### CHAMADAS EXTERNAS - Argumentos do script -----------------------------------------------#
main () {
  case $1 in
    "code_analisys")
      code_analisys "$@"
      ;;
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
      echo "$0-$app_semver $2"
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
