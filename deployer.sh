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

# Aliyun 容器镜像仓库地址
REGISTRY_URL_WAN=registry.cn-shenzhen.aliyuncs.com
REGISTRY_URL_LAN=registry-vpc.cn-shenzhen.aliyuncs.com
# Aliyun 命名空间
REGISTRY_SPACE=synron

function back(){
  cd ${CI_PROJECT_DIR}
}

function clean(){
  cd ${CI_PROJECT_DIR}
  rm -rf *
}
 
function clone(){
  WORK_DIR=`pwd`
  if [ ! -d "${CI_PROJECT_NAME}/pom.xml" ]; then
    \rm -rf ${CI_PROJECT_NAME}
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

#  cd ${CI_PROJECT_NAME}
#   git submodule sync --recursive
#   git submodule update --init --recursive
  back
}

function test(){
  clone
  cd ${CI_PROJECT_NAME}
  mvn test org.jacoco:jacoco-maven-plugin:prepare-agent
  back
}

function build_web(){

  DIRS=`ls -F | grep '/$'`
  for arg in ${DIRS[@]}
  do
    arg=${arg%%/*};
    echo "---${arg}"
    if [[ ! $arg =~ "library" ]]; then
        POM=$arg/pom.xml
        if [ -f "$POM" ];then
          PACKAGE_NAME=`awk '/<package.name>[^<]+<\/package.name>/{gsub(/<package.name>|<\/package.name>/,"",$1);print $1;exit;}' $POM`
          if [ -n "$PACKAGE_NAME" ]; then 
            APP_NAME=`awk '/<artifactId>[^<]+<\/artifactId>/{gsub(/<artifactId>|<\/artifactId>/,"",$1);print $1;exit;}' $POM`
            APP_DIR=$arg;
          fi
        fi
    fi
  done
  echo "发现APP目录: ${APP_DIR}"
  echo "发现APP名称: ${APP_NAME}"
  
  git clone --recursive ${GIT_WEB_URL} web
  cd web
  echo "npm install"
  npm install
  echo "npm run build"
  npm run build
  echo "cp dist"
  
  \cp -rf ./dist/* ../${APP_DIR}/src/main/resources-public/static/
  cd ..
}

function build(){
  clone
  cd ${CI_PROJECT_NAME}
  build_web
  mvn clean $*
  mvn package -P ${PROFILE} -D package.type=jar -D web.server=undertow ${MAVEN_CLI_OPTS}
  TARGET=`find ./ -name *-${PROFILE}-*.jar`
  echo "打包完成:${TARGET}"
  \mv -f ${TARGET} ${CI_PROJECT_DIR}/${APP_NAME}.jar
  back
}

function getHubUrl(){
  PING=`ping 10.0.0.160 -c 1 | grep "time=" | grep "ttl="`
  if [ ! -n "$PING" ] ;then
    echo ${REGISTRY_URL_WAN} 
  else
    echo ${REGISTRY_URL_LAN}
  fi
}

function getImageName(){
  # APP
  # 镜像名称由jar包名获得
  
  JAR=$1
  JAR=${JAR##*/}
  # Aliyun 镜像名称
  REGISTRY_NAME=${JAR%%.*}
  #REGISTRY_NAME=${REGISTRY_NAME%%-*}
  echo ${REGISTRY_NAME}
}

function deploy(){
  echo "----- 发布到 Aliyun 容器镜像服务 -----"
  
  TARGET=`find ./ -name *.jar`
  if [ -n "$TARGET" ]; then 
    echo "发现目标Jar文件: ${TARGET}"
  fi
  REGISTRY_URL=`getHubUrl`
  REGISTRY_NAME=`getImageName ${TARGET}`
  
  # 镜像全名: 用于构建/发布/拉取
  IMAGE_NAME=${REGISTRY_URL}/${REGISTRY_SPACE}/${REGISTRY_NAME}:latest
  IMAGE_DEPLOY_NAME=${REGISTRY_URL}/kluster/alpine-java

  echo "镜像名称${IMAGE_NAME}"
  
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
  # echo y | docker system prune
  docker login -u${REGISTRY_USERNAME} -p${REGISTRY_PASSWORD} ${REGISTRY_URL}
  docker build -t ${IMAGE_NAME} --compress .
  docker images
  docker push ${IMAGE_NAME}
  docker logout ${REGISTRY_URL}

}

# for arg in $@
# do
#   eval "$arg"
# done
eval "$*"
