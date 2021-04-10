#FROM ubuntu:latest
FROM certbot/dns-cloudflare

MAINTAINER Runar Fredagsvik "root@runarsf.dev"

USER root

ENV CRON "${CRON}"
ENV CLOUDFLARE_TOKEN "${CLOUDFLARE_TOKEN}"
ENV DOMAIN "${DOMAIN}"
ENV EMAIL "${EMAIL}"
ENV PROPAGATION "${PROPAGATION}"
ENV ACME_SERVER "${ACME_SERVER}"

ENV RUNLEVEL 1

#RUN apt-get update \
# && DEBIAN_FRONTEND=noninteractive apt-get -y install cron curl \
# && apt-get clean
RUN apk -U upgrade \
 && apk add curl \
            bash \
            iptables \
            ca-certificates \
            e2fsprogs \
            docker \
 && pip install certbot-dns-cloudflare \
 && rm -rf /var/cache/apk/*
            #cron \

# RUN chmod 0744 /etc/cron.d/crontab (cron fails silently if you forget)
# Could write directly to file instead of copy, would remove the need for envsubst and gettext
#COPY crontab /etc/cron.d/crontab
#RUN envsubst < "/etc/cron.d/crontab" | tee "/etc/cron.d/crontab"
RUN mkdir -p /etc/cron.d \
 && touch /etc/cron.d/crontab

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/crontab

# Apply cron job (done in docker-entrypoint.sh)
#RUN crontab /etc/cron.d/crontab

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]

# Cron in foreground, requires cron commands to manually redirect to stdout
# > /proc/1/fd/1 2>/proc/1/fd/2
#CMD cron -f
