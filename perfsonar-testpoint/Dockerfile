# perfSONAR Testpoint

FROM ubuntu:22.04

ENV container=docker
ENV LC_ALL=C
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y vim curl gnupg rsyslog net-tools less sysstat iproute2 dnsutils tcpdump software-properties-common supervisor jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------

#
# PostgreSQL Server
#

ENV PG_VERSION=14 \
    PG_USER=postgres

ENV PG_HOME=/etc/postgresql/$PG_VERSION/main \ 
    PG_BINDIR=/usr/lib/postgresql/$PG_VERSION/bin \
    PGDATA=/var/lib/postgresql/$PG_VERSION/main

RUN apt-get update \
    && apt-get install -y postgresql-$PG_VERSION postgresql-client-$PG_VERSION \
    && rm -rf $PGDATA

RUN su - $PG_USER -c "$PG_BINDIR/pg_ctl init -D $PGDATA"
     
COPY --chown=$PG_USER:$PG_USER postgresql/postgresql.conf $PG_HOME/postgresql.conf
COPY --chown=$PG_USER:$PG_USER postgresql/pg_hba.conf $PG_HOME/pg_hba.conf

RUN su - $PG_USER -c "$PG_BINDIR/pg_ctl start -w -t 60 -D $PGDATA"

# -----------------------------------------------------------------------

# Rsyslog

COPY rsyslog/rsyslog /etc/init.d/rsyslog
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/listen.conf /etc/rsyslog.d/listen.conf
COPY rsyslog/python-pscheduler.conf /etc/rsyslog.d/python-pscheduler.conf
COPY rsyslog/owamp-syslog.conf /etc/rsyslog.d/owamp-syslog.conf

# -----------------------------------------------------------------------------

RUN curl -o /etc/apt/sources.list.d/perfsonar-release.list https://downloads.perfsonar.net/debian/perfsonar-release.list \
    && curl https://downloads.perfsonar.net/debian/perfsonar-release.gpg.key | apt-key add - \
    && add-apt-repository universe

RUN apt-get update \
    && apt-get install -y perfsonar-testpoint \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# Home Assistant add-on additions (not in upstream perfsonar-testpoint-docker):
#  - run perfSONAR's own node_exporter (host metrics; upstream never starts it)
#  - SINDAN Wi-Fi exporter (non-aggressive neighbour scan only), feeding
#    node_exporter's textfile collector. Pinned to a sindan-client commit.

ARG SINDAN_REF=ff73abc62559567874af8a680a557493a5e65741

RUN apt-get update \
    && apt-get install -y iw \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /opt/sindan /var/lib/prometheus/node-exporter \
    && curl -fsSL https://github.com/ikob/sindan-client/archive/${SINDAN_REF}.tar.gz \
       | tar -xz -C /opt/sindan --strip-components=2 \
           sindan-client-${SINDAN_REF}/linux/sindan_exporter.sh \
           sindan-client-${SINDAN_REF}/linux/sindan_func1.sh

COPY rootfs/node-exporter.sh /usr/local/bin/node-exporter.sh
COPY rootfs/sindan-exporter-loop.sh /usr/local/bin/sindan-exporter-loop.sh
RUN chmod +x /usr/local/bin/node-exporter.sh /usr/local/bin/sindan-exporter-loop.sh

# -----------------------------------------------------------------------------

RUN mkdir -p /var/log/supervisor 
ADD supervisord.conf /etc/supervisord.conf

# The following ports are used:
# pScheduler: 443
# owamp:861, 8760-9960 (tcp and udp)
# twamp: 862, 18760-19960 (tcp and udp)
# simplestream: 5890-5900
# nuttcp: 5000, 5101
# iperf2: 5001
# iperf3: 5201
# ntp: 123 (udp)
EXPOSE 123/udp 443 861 862 5000 5001 5101 5201 5890-5900 8760-9960/tcp 8760-9960/udp 18760-19960/tcp 18760-19960/udp

# add pid directory, logging, and postgres directory
VOLUME ["/var/run", "/var/lib/pgsql", "/var/log", "/etc/rsyslog.d" ]

# -----------------------------------------------------------------------------
# Home Assistant add-on wrapper: injects HA options (psconfig_host,
# syslog_target, wifi_*) into the config files above, then execs the same
# supervisord command as upstream.
COPY rootfs/run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
