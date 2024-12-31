FROM golang:alpine AS builder

# for GFW
ENV GOPROXY=https://goproxy.cn,direct

RUN go install gitee.com/we-mid/go/mpwx/cmd/wxpush@latest

FROM alpine AS runtime

# （Docker）Alpine apk设置国内源
# https://www.cnblogs.com/langkyeSir/p/15323361.html
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk update

# 设置时区为亚洲/上海
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

RUN apk add --no-cache curl

COPY --from=builder /go/bin/wxpush /go/bin/
ENV PATH=$PATH:/go/bin

WORKDIR /app

COPY *.sh .
RUN chmod +x *.sh
RUN ./install_cron.sh

CMD ./health_check.sh 2 >> data/health.log 2>&1 && crond && tail -f data/*.log
