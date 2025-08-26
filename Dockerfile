FROM alpine:latest

MAINTAINER MarkusMcNugen
# Enhanced with automatic SSL certificate management using acme.sh

VOLUME /etc/ocserv

# Install dependencies including acme.sh requirements
RUN buildDeps=" \
		curl \
		g++ \
		gawk \
		geoip \
		gnutls-dev \
		gpgme \
		krb5-dev \
		libc-dev \
		libev-dev \
		libnl3-dev \
		libproxy \
		libseccomp-dev \
		libtasn1 \
		linux-headers \
		linux-pam-dev \
		lz4-dev \
		make \
		oath-toolkit-liboath \
		oath-toolkit-libpskc \
		p11-kit \
		pcsc-lite-libs \
		protobuf-c \
		readline-dev \
		scanelf \
		stoken-dev \
		tar \
		tpm2-tss-esys \
		xz \
	"; \
	set -x \
	&& apk add --update --virtual .build-deps $buildDeps \
	# The line below grabs the 2nd most recent version of OC
	&& export OC_VERSION=$(curl --silent "https://ocserv.gitlab.io/www/changelog.html" 2>&1 | grep -m 2 'Version' | tail -n 1 | awk '/Version/ {print $2}') \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /usr/src/ocserv \
	&& runDeps="$( \
			scanelf --needed --nobanner /usr/local/sbin/ocserv \
				| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
				| xargs -r apk info --installed \
				| sort -u \
			)" \
	&& apk add --update --virtual .run-deps $runDeps gnutls-utils iptables \
	&& apk del .build-deps \
	&& rm -rf /var/cache/apk/* 

# Install runtime dependencies and acme.sh requirements
RUN apk add --update bash rsync ipcalc sipcalc ca-certificates rsyslog logrotate runit \
	socat openssl coreutils grep sed gawk findutils \
	&& rm -rf /var/cache/apk/* 

RUN update-ca-certificates

# Install acme.sh
RUN curl -s https://get.acme.sh | sh -s email=admin@example.com \
	&& ln -s ~/.acme.sh/acme.sh /usr/local/bin/acme.sh

# Copy configuration files and scripts
ADD ocserv /etc/default/ocserv
COPY docker-entrypoint.sh /entrypoint.sh
COPY ssl-manager.sh /usr/local/bin/ssl-manager.sh
COPY check-ssl-cron.sh /usr/local/bin/check-ssl-cron.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /usr/local/bin/ssl-manager.sh /usr/local/bin/check-ssl-cron.sh

# Create cron entry for SSL certificate checking (every 12 hours)
RUN echo "0 */12 * * * /usr/local/bin/check-ssl-cron.sh >> /etc/ocserv/logs/ssl-check.log 2>&1" > /var/spool/cron/crontabs/root

WORKDIR /etc/ocserv

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 4443
EXPOSE 4443/udp
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]