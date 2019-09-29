FROM golang:1.13-alpine AS builder

RUN apk add \
        ca-certificates \
        git

WORKDIR /app
COPY go.mod go.sum /app/
RUN go mod download

COPY . /app/
RUN CGO_ENABLED=0 go build -a -installsuffix cgo -ldflags="-s -w" -o build/app

FROM scratch

COPY --from=builder /app/build/app /
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["./app"]
