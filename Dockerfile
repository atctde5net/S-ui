# Dockerfile
FROM --platform=$BUILDPLATFORM node:20-alpine AS front-builder
WORKDIR /app
COPY frontend/ ./
RUN npm ci --only=production && npm run build

FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS backend-builder
WORKDIR /app
ARG TARGETARCH
ARG TARGETOS
ENV CGO_ENABLED=1
ENV GOARCH=$TARGETARCH
ENV GOOS=$TARGETOS

RUN apk add --no-cache \
    gcc \
    musl-dev \
    git \
    make

COPY go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=front-builder /app/dist/ /app/web/html/

RUN go build -ldflags="-w -s" \
    -tags "with_quic,with_grpc,with_utls,with_acme,with_gvisor" \
    -o sui main.go

FROM --platform=$TARGETPLATFORM alpine:3.19
LABEL org.opencontainers.image.authors="alireza7@gmail.com"
ENV TZ=Asia/Tehran
WORKDIR /app

RUN apk add --no-cache --upgrade \
    bash \
    tzdata \
    ca-certificates \
    nftables \
    && update-ca-certificates \
    && mkdir -p /app/db /app/cert /app/bin

COPY --from=backend-builder --chmod=755 /app/sui /app/
COPY --chmod=755 entrypoint.sh /app/

EXPOSE 2095 2096 80 443

ENTRYPOINT [ "./entrypoint.sh" ]
