# builder
FROM --platform=$BUILDPLATFORM golang:1.25.7 AS builder
ARG GOPROXY=https://proxy.golang.org,direct
ENV GOPROXY=$GOPROXY
WORKDIR /go/src/github.com/gardener/gardener-landscape-kit
COPY . .
ARG EFFECTIVE_VERSION
ARG TARGETOS
ARG TARGETARCH

RUN make build EFFECTIVE_VERSION=$EFFECTIVE_VERSION GOOS=$TARGETOS GOARCH=$TARGETARCH BUILD_OUTPUT_FILE="/output/bin/"
# distroless-static
FROM gcr.io/distroless/static-debian12:nonroot AS distroless-static

# gardener-landscape-kit
FROM distroless-static AS gardener-landscape-kit
COPY --from=builder /output/bin/gardener-landscape-kit /gardener-landscape-kit
WORKDIR /
ENTRYPOINT ["/gardener-landscape-kit"]
