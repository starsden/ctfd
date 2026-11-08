# Multi-stage build для объединения frps и frpc в единый образ local-frp
FROM fatedier/frps:v0.61.2 AS frps_bin
FROM fatedier/frpc:v0.61.2 AS frpc_bin
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=frps_bin /usr/bin/frps /usr/local/bin/frps
COPY --from=frpc_bin /usr/bin/frpc /usr/local/bin/frpc
