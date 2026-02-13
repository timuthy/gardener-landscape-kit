#
# SPDX-FileCopyrightText: SAP SE or an SAP affiliate company and Gardener contributors
#
# SPDX-License-Identifier: Apache-2.0

export PACKAGE_PATH="${1:-k8s.io/component-base}"
export VERSION_PATH="${2:-$(dirname $0)/../VERSION}"
export PROGRAM_NAME="${3:-Gardener-Landscape-kit}"
export VERSION_VERSIONFILE="$(cat "$VERSION_PATH")"
export VERSION="${EFFECTIVE_VERSION:-$VERSION_VERSIONFILE}"

MAJOR_VERSION=""
MINOR_VERSION=""

if [[ "${VERSION}" =~ ^v([0-9]+)\.([0-9]+)(\.[0-9]+)?([-].*)?([+].*)?$ ]]; then
  MAJOR_VERSION=${BASH_REMATCH[1]}
  MINOR_VERSION=${BASH_REMATCH[2]}
  if [[ -n "${BASH_REMATCH[4]}" ]]; then
    MINOR_VERSION+="+"
  fi
fi

export MAJOR_VERSION=$MAJOR_VERSION
export MINOR_VERSION=$MINOR_VERSION
