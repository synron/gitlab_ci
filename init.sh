#!/bin/sh
set -eu

echo "查看系统变量"
echo ${CI_PROJECT_URL}
echo ${CI_PROJECT_DIR}
echo ${CI_PROJECT_NAME}:${CI_COMMIT_REF_NAME}


echo "初始化构建脚本"
wget -q -O gitlab_ci https://raw.githubusercontent.com/synron/gitlab_ci/master/deployer_mvn.sh
chmod +x gitlab_ci
\mv -f gitlab_ci /usr/local/bin/gitlab_ci

# which gitlab_ci

