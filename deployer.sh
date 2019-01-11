#!/bin/sh
set -eu


# 配置gitlab-runner缓存
# 持久化:
# vim /opt/data/gitlab-runner/config/config.toml
# volumes = ["/opt/data/gitlab-runner/cache:/cache:rw"]


export M2_CACHE=/cache/.m2/
export MAVEN_OPTS="-Dmaven.repo.local=${M2_CACHE}/repository"
export GRADLE_OPTS="-Dgradle.user.home=${M2_CACHE}/.gradle"

MAVEN_CLI_OPTS="-B -e -U -Dmaven.test.skip=true"

# APP
# 镜像名称由jar包名获得
TARGET=`find ./ -name *.jar`
TARGET=${TARGET##*/}
echo "发现Jar文件: ${TARGET}"

# Aliyun 容器镜像仓库地址
REGISTRY_URL=registry.cn-shenzhen.aliyuncs.com
# Aliyun 命名空间
REGISTRY_SPACE=synron
# Aliyun 镜像名称
REGISTRY_NAME=${TARGET%%.*}
# echo ${REGISTRY_NAME}

# 镜像全名: 用于构建/发布/拉取
IMAGE_NAME=${REGISTRY_URL}/${REGISTRY_SPACE}/${REGISTRY_NAME}:latest
  
IMAGE_DEPLOY_NAME=registry.cn-shenzhen.aliyuncs.com/kluster/alpine-java

function back(){
  cd ${CI_PROJECT_DIR}
}

function clone(){
  WORK_DIR=`pwd`
  if [ ! -d "${CI_PROJECT_NAME}" ]; then
    echo "--------- 初始化 git -----------"
    echo https://${GIT_USERNAME}:${GIT_PASSWORD}@gitlab.synron.cn > ~/.git-credentials
    git config --global user.name ${GIT_USERNAME}
    git config --global user.password ${GIT_PASSWORD}
    git config --global credential.helper store
    echo "--------- 克隆源代码 -----------"
    git clone --recursive -b ${GIT_TAG} --depth=${GIT_DEPTH} ${CI_REPOSITORY_URL}
  else
    echo "--------- 源码已存在 -----------"
  fi

  cd ${CI_PROJECT_NAME}
  git submodule sync --recursive
  git submodule update --init --recursive
  back
}

function test(){
  rm -rf *
  clone
  cd ${CI_PROJECT_NAME}
  mvn test org.jacoco:jacoco-maven-plugin:prepare-agent
  back
}

function build_web(){
  git clone --recursive ${GIT_WEB_URL} web
  cd web
  echo "npm install"
  npm install
  echo "npm run build"
  npm run build
  echo "cp dist"
  \cp -rf ./dist/* ../app/src/main/resources-public/static/
  cd ..
}

function build(){
  rm -rf *
  clone
  cd ${CI_PROJECT_NAME}
  build_web
  mvn clean package -P ${PROFILE} ${MAVEN_CLI_OPTS}
  TARGET=`find ./ -name *-${PROFILE}-*.jar`
  \mv -f ${TARGET} ${CI_PROJECT_DIR}/
  back
}

function deploy(){
  echo "----- 发布到 Aliyun 容器镜像服务 -----"

  cd ${CI_PROJECT_DIR}
  local WORKDIR=.docker
  mkdir -p ${WORKDIR} && \mv -f ${TARGET} ${WORKDIR}/ && cd ${WORKDIR}

  echo "" > Dockerfile
  echo "FROM ${IMAGE_DEPLOY_NAME}" >> Dockerfile
  echo "WORKDIR /opt" >> Dockerfile
  echo "ADD ${TARGET} app.jar" >> Dockerfile
  echo "ENTRYPOINT [\"java\", \"-jar\", \"app.jar\", \"--server.port=80\"]" >> Dockerfile
  echo "" >> Dockerfile
  cat Dockerfile

  docker images
  echo y | docker system prune
  docker login -u${REGISTRY_USERNAME} -p${REGISTRY_PASSWORD} ${REGISTRY_URL}
  docker build -t ${IMAGE_NAME} --compress .
  docker images
  docker push ${IMAGE_NAME}
  docker logout ${REGISTRY_URL}

}

for arg in $@
do
  eval "$arg"
done
