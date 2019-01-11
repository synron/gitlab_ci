#!/bin/sh
set -eu

echo ${CI_PROJECT_URL}
echo ${CI_PROJECT_DIR}
echo ${CI_PROJECT_NAME}:${CI_COMMIT_REF_NAME}



wget -q -O gitlab_ci https://raw.githubusercontent.com/synron/gitlab_ci/master/mvn.sh
chmod +x gitlab_ci
\mv -f gitlab_ci /usr/local/bin/gitlab_ci
