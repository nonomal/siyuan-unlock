FROM node:21 as NODE_BUILD
WORKDIR /go/src/github.com/appdev/siyuan-unlock/
ADD . /go/src/github.com/appdev/siyuan-unlock/
RUN apt-get update && \
    apt-get install -y jq
RUN cd app && \
packageManager=$(jq -r '.packageManager' package.json) && \
if [ -n "$packageManager" ]; then \
    npm install -g $packageManager; \
else \
    echo "No packageManager field found in package.json"; \
    npm install -g pnpm; \
fi && \
npm config set registry http://registry.npmmirror.com && \
npm install && npm run build
RUN apt-get purge -y jq
RUN apt-get autoremove -y
RUN rm -rf /var/lib/apt/lists/*

FROM golang:alpine as GO_BUILD
WORKDIR /go/src/github.com/appdev/siyuan-unlock/
COPY --from=NODE_BUILD /go/src/github.com/appdev/siyuan-unlock/ /go/src/github.com/appdev/siyuan-unlock/
ENV GO111MODULE=auto
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN apk add --no-cache gcc musl-dev && \
    cd kernel && go build --tags fts5 -v -ldflags "-s -w -X github.com/appdev/siyuan-unlock/kernel/util.Mode=prod" && \
    mkdir /opt/siyuan/ && \
    mv /go/src/github.com/appdev/siyuan-unlock/app/appearance/ /opt/siyuan/ && \
    mv /go/src/github.com/appdev/siyuan-unlock/app/stage/ /opt/siyuan/ && \
    mv /go/src/github.com/appdev/siyuan-unlock/app/guide/ /opt/siyuan/ && \
    mv /go/src/github.com/appdev/siyuan-unlock/app/changelogs/ /opt/siyuan/ && \
    mv /go/src/github.com/appdev/siyuan-unlock/kernel/kernel /opt/siyuan/ && \
    find /opt/siyuan/ -name .git | xargs rm -rf

FROM alpine:latest
LABEL maintainer="Liang Ding<845765@qq.com>"

WORKDIR /opt/siyuan/
COPY --from=GO_BUILD /opt/siyuan/ /opt/siyuan/
RUN addgroup --gid 1000 siyuan && adduser --uid 1000 --ingroup siyuan --disabled-password siyuan && apk add --no-cache ca-certificates tzdata && chown -R siyuan:siyuan /opt/siyuan/

ENV TZ=Asia/Shanghai
ENV RUN_IN_CONTAINER=true
EXPOSE 6806

USER siyuan
ENTRYPOINT ["/opt/siyuan/kernel"]
