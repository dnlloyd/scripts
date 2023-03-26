mkdir -p deploy/bases/v0.0.1

for ENV in $(ls -1 vars |grep -v local);
do
  mkdir -p deploy/overlays/${ENV}
  touch deploy/overlays/${ENV}/kustomization.yaml
  cat > deploy/overlays/${ENV}/kustomization.yaml <<EOL
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - ../../bases/v0.0.1
EOL

  APP_VERSION=`node -p "require('./package.json').version" `
  GIT_VERSION=`git describe --match=NeVeRmAtCh --always --dirty`
  FULL_VERSION="v${APP_VERSION}-g${GIT_VERSION}-kustomization"
  SERVICE=$1

  OUTPUT_DIR="deploy/bases/v0.0.1/originals/original-${ENV}"

  # Ex: helm template "charts/ciitizen-sharing-service-v2" --namespace=default --set image.tag=v0.0.1-g1759b01-kustomization -f vars/dev/values.yaml --output-dir $OUTPUT_DIR
  helm template "charts/${SERVICE}" --namespace=${ENV} --set image.tag=${FULL_VERSION} -f vars/${ENV}/values.yaml --output-dir $OUTPUT_DIR

  # Prep configmapGenerator if configmap file exists
  if [ -f "deploy/bases/v0.0.1/originals/original-${ENV}/${SERVICE}/templates/configmap.yaml" ]
  then
    echo "Configmap file detected, adding to overlays"
    echo "" >> deploy/overlays/${ENV}/kustomization.yaml
    echo "configmapGenerator:" >> deploy/overlays/${ENV}/kustomization.yaml
    echo "- name: ${SERVICE}-configmap" >> deploy/overlays/${ENV}/kustomization.yaml
  fi

  if [[ "${ENV}" == "dev" ]]
  then
    echo "Creating base files from dev environment in deploy/bases/v0.0.1 "
    cp -R deploy/bases/v0.0.1/originals/original-${ENV}/${SERVICE}/templates/*.yaml deploy/bases/v0.0.1/
  fi
done

touch deploy/bases/v0.0.1/kustomization.yaml

cat > deploy/bases/v0.0.1/kustomization.yaml <<EOL
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
EOL

# Defining resource files in base kustomization
ls -1 deploy/bases/v0.0.1/ |egrep -v "originals|kustomization.yaml|configmap.yaml" | sed "s/^/- .\//g" >> deploy/bases/v0.0.1/kustomization.yaml

# Don't use the configmap file if it exists
if  [ -f "deploy/bases/v0.0.1/configmap.yaml" ]
then
  echo "Configmap file detected, removing"
  rm -f deploy/bases/v0.0.1/configmap.yaml
fi
