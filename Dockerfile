# Build Stage
FROM golang:1.21-alpine AS builder
RUN apk add --no-cache git make
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o fast-note-sync-service main.go

# Production Stage
FROM alpine:latest
RUN apk add --no-cache ca-certificates tzdata bash gettext
WORKDIR /fast-note-sync

# Copy binary and configuration templates
COPY --from=builder /app/fast-note-sync-service /fast-note-sync/fast-note-sync-service
COPY config.yaml.template /fast-note-sync/config.yaml.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Northflank binds port dynamically, but we expose 9000 as default
EXPOSE 9000
ENTRYPOINT ["/entrypoint.sh"]
