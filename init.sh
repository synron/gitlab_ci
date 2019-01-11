#!/bin/sh
set -eu

echo ${CI_PROJECT_URL}
echo ${CI_PROJECT_DIR}
echo ${CI_PROJECT_NAME}:${CI_COMMIT_REF_NAME}



wget -q https://raw.githubusercontent.com/synron/gitlab_ci/master/function.sh
chmod +x function.sh
\cp -rf function.sh /usr/local/bin/gitlab_ci
