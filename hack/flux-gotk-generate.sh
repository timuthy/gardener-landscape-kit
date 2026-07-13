#!/usr/bin/env bash

# SPDX-FileCopyrightText: SAP SE or an SAP affiliate company and Gardener contributors
#
# SPDX-License-Identifier: Apache-2.0

alias flux=$FLUX_CLI

echo "> Generating Flux components"
flux install \
  --export \
  > $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-components.yaml
flux create secret git flux-system \
  --url="https://github.com/<org>/<repo>" \
  --username="<username>" \
  --password="<git_token>" \
  --export \
  > $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/git-sync-secret.yaml
flux create source git flux-system \
  --branch "<branch>" \
  --secret-ref flux-system --url "https://github.com/<org>/<repo>" \
  --recurse-submodules \
  --export \
  > $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-sync.yaml
flux create kustomization flux-system \
  --interval 10m \
  --path "{{ .flux_path }}" \
  --source GitRepository/flux-system \
  --export \
  >> $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-sync.yaml

# Some post processing is needed because the flux CLI does not accept template variables everywhere.

## Replace URL placeholder with Helm template variables
sed -i 's|https://github.com/<org>/<repo>|{{ .repo_url }}|g' $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-sync.yaml

## Replace branch placeholder
sed -i 's|branch\:\s<branch>|{{ .repo_ref }}|g' $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-sync.yaml

## Add comment for recurseSubmodules
sed -i -e 's/recurseSubmodules: true/recurseSubmodules: true # required if Git submodules are used, e.g. to include the base repo in the landscape repo./g' \
  $REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-sync.yaml

GOTK=$REPO_ROOT/pkg/components/flux/templates/landscape/flux-system/gotk-components.yaml
COMPONENTS=$REPO_ROOT/componentvector/components.yaml
OCM_BASE_COMPONENT=$REPO_ROOT/.ocm/base-component.yaml

# Convert a hyphenated controller name to camelCase key, e.g. "source-controller" -> "sourceController"
to_camel_case() {
  echo "$1" | sed -E 's/-([a-z])/\U\1/g'
}

GLK_INDEX=$(yq '.components | to_entries | .[] | select(.value.name == "github.com/gardener/gardener-landscape-kit") | .key' "$COMPONENTS")

## Extract all Flux controller images from gotk-components.yaml and update downstream files
echo "> Updating Flux controller images in componentvector/components.yaml and .ocm/base-component.yaml"

# Clear existing Flux controller resources so stale entries don't accumulate.
GLK_INDEX=$GLK_INDEX yq -i '.components[env(GLK_INDEX)].resources = {}' "$COMPONENTS"
ocm_resources_file=$(mktemp)
echo "[]" > "$ocm_resources_file"

while IFS= read -r image; do
  # image is e.g. "ghcr.io/fluxcd/source-controller:v1.8.5"
  controller="${image#ghcr.io/fluxcd/}"   # "source-controller:v1.8.5"
  controller="${controller%%:*}"           # "source-controller"
  tag="${image##*:}"                       # "v1.8.5"
  repo="${image%:*}"                       # "ghcr.io/fluxcd/source-controller"
  resource_key=$(to_camel_case "$controller")

  GLK_INDEX=$GLK_INDEX resource_key=$resource_key repo=$repo tag=$tag \
    yq -i '.components[env(GLK_INDEX)].resources[env(resource_key)].ociImage.repository = env(repo) |
           .components[env(GLK_INDEX)].resources[env(resource_key)].ociImage.tag = env(tag)' "$COMPONENTS"

  controller=$controller tag=$tag image=$image \
    yq -i '. += [{"name": env(controller), "version": env(tag), "type": "ociImage", "relation": "external", "access": {"type": "ociRegistry", "imageReference": env(image)}}]' \
    "$ocm_resources_file"

  sed -i "s|image: ${image}|image: {{ .resources.${resource_key}.ociImage.ref }}|g" "$GOTK"
done < <(grep -oP "(?<=image: )ghcr\.io/fluxcd/[^\s]+" "$GOTK" | sort -u)

resources_file=$ocm_resources_file yq -i '.resources = load(env(resources_file))' "$OCM_BASE_COMPONENT"
rm "$ocm_resources_file"
