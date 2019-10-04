FROM golang:1.11.5-stretch

ARG NGROK_BASE_DOMAIN=foo.bar.com
ARG NGROK_SERVER_KEY=assets/server/tls/server.key
ARG NGROK_SERVER_CSR=assets/server/tls/server.csr
ARG NGROK_SERVER_CRT=assets/server/tls/server.crt
ARG NGROK_GIT=https://github.com/inconshreveable/ngrok.git
ARG NGROK_DIR=/ngrok
ARG NGROK_TMP=/tmp/ngrok
ARG NGROK_CA_KEY=assets/client/tls/ngrokroot.key
ARG NGROK_CA_CRT=assets/client/tls/ngrokroot.crt

ENV NGROK_BASE_DOMAIN=$NGROK_BASE_DOMAIN

WORKDIR $NGROK_DIR

RUN apt-get update \
    && apt-get install -y build-essential \
                          curl \
                          git \
                          mercurial \
    && git clone ${NGROK_GIT} ${NGROK_TMP} \
    && cd ${NGROK_TMP} \
    && openssl genrsa -out ${NGROK_CA_KEY} 2048 \
    && openssl req -new -x509 -nodes -key ${NGROK_CA_KEY} -subj "/CN=${NGROK_BASE_DOMAIN}" -days 365 -out ${NGROK_CA_CRT} \
    && openssl genrsa -out ${NGROK_SERVER_KEY} 2048 \
    && openssl req -new -key ${NGROK_SERVER_KEY} -subj "/CN=${NGROK_BASE_DOMAIN}" -out ${NGROK_SERVER_CSR} \
    && openssl x509 -req -in ${NGROK_SERVER_CSR} -CA ${NGROK_CA_CRT} -CAkey ${NGROK_CA_KEY} -CAcreateserial -days 365 -out ${NGROK_SERVER_CRT} \
    && for GOOS in linux; \
       do \
         for GOARCH in amd64; \
         do \
           echo "=== $GOOS-$GOARCH ==="; \
           export GOOS GOARCH; \
           make release-all; \
           echo "=== done ==="; \
         done \
       done \
    && mv ${NGROK_CA_KEY} \
          ${NGROK_CA_CRT} \
          ${NGROK_SERVER_KEY} \
          ${NGROK_SERVER_CSR} \
          ${NGROK_SERVER_CRT} \
          ./bin/* \
          ${NGROK_DIR} \
    && apt-get purge --auto-remove -y build-essential \
                                      curl \
                                      git \
                                      mercurial \
    && cd ${NGROK_DIR} \
    && echo "server_addr: ${NGROK_BASE_DOMAIN}:4443" >> ngrok.yml \
    && echo "trust_host_root_certs: true" >> ngrok.yml \
    && rm -rf ${NGROK_TMP}

VOLUME $NGROK_DIR
EXPOSE 80 443 4443

ENTRYPOINT ["sh", "-c", "./ngrokd -domain=${NGROK_BASE_DOMAIN} -tlsCrt=server.crt -tlsKey=server.key"]
