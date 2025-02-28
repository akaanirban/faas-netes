FROM golang:1.11 as build
ENV CGO_ENABLED=0

RUN curl -sLSf https://raw.githubusercontent.com/teamserverless/license-check/master/get.sh | sh
RUN mv ./license-check /usr/bin/license-check && chmod +x /usr/bin/license-check

WORKDIR /go/src/github.com/akaanirban/faas-netes
COPY . .

RUN license-check -path /go/src/github.com/akaanirban/faas-netes/ --verbose=false "Alex Ellis" "OpenFaaS Author(s)"
RUN gofmt -l -d $(find . -type f -name '*.go' -not -path "./vendor/*") \
    && go test ./... \
    && VERSION=$(git describe --all --exact-match `git rev-parse HEAD` | grep tags | sed 's/tags\///') \
    && GIT_COMMIT=$(git rev-list -1 HEAD) \
    && CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w \
        -X github.com/akaanirban/faas-netes/version.GitCommit=${GIT_COMMIT}\
        -X github.com/akaanirban/faas-netes/version.Version=${VERSION}" \
        -a -installsuffix cgo -o faas-netes .

FROM alpine:3.10 as ship

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/akaanirban/faas-netes" \
      org.label-schema.vcs-type="Git" \
      org.label-schema.name="akaanirban/faas-netes" \
      org.label-schema.vendor="anirban" \
      org.label-schema.docker.schema-version="1.0"

RUN addgroup -S app \
    && adduser -S -g app app \
    && apk --no-cache add \
    ca-certificates

WORKDIR /home/app

EXPOSE 8080

ENV http_proxy      ""
ENV https_proxy     ""

COPY --from=0 /go/src/github.com/akaanirban/faas-netes/faas-netes    .
RUN chown -R app:app ./

USER app

CMD ["./faas-netes"]
