FROM martenseemann/quic-network-simulator-endpoint:latest AS builder

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install -qy mercurial build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev curl git cmake ninja-build gnutls-bin iptables autoconf libtool

RUN useradd nginx

RUN git clone https://github.com/libressl/portable
RUN cd portable && ./autogen.sh && ./configure && make dist && tar xvf libressl-* && cd libressl-* && ./configure && make -j$(nproc) && make install

RUN cp /usr/local/lib/libssl.so.* /usr/local/lib/libcrypto.so.* /lib64

RUN git clone https://github.com/webserver-llc/angie nginx

RUN cd nginx && \
    ./configure --prefix=/etc/nginx \
    --build=111 \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-debug \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-cc=c++ \
    --with-cc-opt='-I/usr/local/include -O0 -fno-common -fno-omit-frame-pointer -DNGX_QUIC_DRAFT_VERSION=29 -DNGX_HTTP_V3_HQ=1 -x c' \
    --with-ld-opt='-L/usr/local/lib/ssl -L/usr/local/lib/crypto'

RUN cd nginx && make -j$(nproc)
RUN cd nginx && make install


FROM martenseemann/quic-network-simulator-endpoint:latest

COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/local/lib/* /usr/local/lib

RUN useradd nginx
RUN mkdir -p /var/cache/nginx /var/log/nginx/

COPY nginx.conf nginx.conf.retry nginx.conf.http3 nginx.conf.nodebug /etc/nginx/

COPY run_endpoint.sh .
RUN chmod +x run_endpoint.sh

EXPOSE 443/udp
EXPOSE 443/tcp

ENTRYPOINT [ "./run_endpoint.sh" ]
