# ── Build stage ──
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev

# Copy source code and build without strict go.sum verification
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GONOSUMDB=* GOSUMDB=off go build -mod=mod -o /gateway ./cmd/main.go

# ── Runtime stage ──
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /gateway /gateway
COPY --from=builder /app/data /app/data

EXPOSE 3000

CMD ["/gateway"]

