#!/bin/sh
set -eu

# Aliyun 容器镜像仓库地址
REGISTRY_URL_WAN=registry.cn-shenzhen.aliyuncs.com
REGISTRY_URL_LAN=registry-vpc.cn-shenzhen.aliyuncs.com
# Aliyun 命名空间
REGISTRY_SPACE=synron


function getHubUrl(){
  PING=`ping 10.0.0.160 -c 1 | grep "time=" | grep "ttl="`
  if [ ! -n "$PING" ] ;then
    echo ${REGISTRY_URL_WAN} 
  else
    echo ${REGISTRY_URL_LAN}
  fi
}

function deploy(){
  echo "----- 发布到 Aliyun 容器镜像服务 -----"
  
  REGISTRY_URL=`getHubUrl`
  REGISTRY_NAME=synrongroup
  
  # 镜像全名: 用于构建/发布/拉取
  IMAGE_NAME=${REGISTRY_URL}/${REGISTRY_SPACE}/${REGISTRY_NAME}:latest
  IMAGE_DEPLOY_NAME=nginx

  echo "镜像名称${IMAGE_NAME}"
  
  echo "" > Dockerfile
  echo "FROM ${IMAGE_DEPLOY_NAME}" >> Dockerfile
  echo "WORKDIR /usr/share/nginx/html/" >> Dockerfile
  echo "ADD ./ /usr/share/nginx/html/" >> Dockerfile
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

deploy;
