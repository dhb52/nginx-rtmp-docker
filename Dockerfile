FROM buildpack-deps:bullseye

# adapted from tiangolo/nginx-rtmp-docker
LABEL maintainer="dhb52 <dhb52@126.com>"

# Versions of Nginx and nginx-http-flv-module to use
ENV NGINX_VERSION nginx-1.23.2
ENV NGINX_HTTP_FLV_MODULE_VERSION 1.2.10
ENV TZ=Asia/Shanghai

RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# Install dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates openssl libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Download and decompress Nginx
COPY src/${NGINX_VERSION}.tar.gz /tmp/build/nginx/${NGINX_VERSION}.tar.gz
RUN cd /tmp/build/nginx && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
COPY src/nginx-http-flv-module-${NGINX_HTTP_FLV_MODULE_VERSION}.zip \
    /tmp/build/nginx-http-flv-module/nginx-http-flv-module-${NGINX_HTTP_FLV_MODULE_VERSION}.zip

RUN cd /tmp/build/nginx-http-flv-module && \
    unzip nginx-http-flv-module-${NGINX_HTTP_FLV_MODULE_VERSION}.zip

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
    --sbin-path=/usr/local/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx/nginx.pid \
    --lock-path=/var/lock/nginx/nginx.lock \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/tmp/nginx-client-body \
    --with-http_ssl_module \
    --with-threads \
    --with-ipv6 \
    --with-http_secure_link_module \
    --with-http_flv_module \
    --add-module=/tmp/build/nginx-http-flv-module/nginx-http-flv-module-${NGINX_HTTP_FLV_MODULE_VERSION} --with-debug && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

RUN mkdir -p "/data/www/rtmp" \
    && mkdir "/data/hls" \
    && mkdir "/data/dash" \
    && mkdir "/data/flv" \
    && mkdir "/data/logs"

RUN chown -R nobody:nogroup /data

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 1935
EXPOSE 80
# VOLUME [ "/data" ]
CMD ["nginx", "-g", "daemon off;"]
