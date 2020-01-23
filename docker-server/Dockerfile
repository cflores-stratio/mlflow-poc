FROM docker-example
MAINTAINER Stratio Rocket <rocket@stratio.com>

RUN apt-get -qq update \
    && apt-get install -y -qq --no-install-recommends \
    locales \
    curl \
    bzip2 \
    wget \
    unzip \
    ca-certificates \
    sudo \
    apt-utils \
    git \
    build-essential \
    libsm6 \
    libxrender1 \
    libpq-dev \
    jq \
    gettext-base \
    iproute2 \
    && apt-get -qq clean \
    && rm -rf /var/lib/apt/lists/*

ADD http://sodio.stratio.com/repository/paas/log_utils/0.4.2/b-log-0.4.2.sh /b-log.sh
ADD http://sodio.stratio.com/repository/paas/kms_utils/0.4.2/kms_utils-0.4.2.sh /kms_utils.sh

COPY entrypoint.sh /entrypoint.sh

CMD ["bash", "/entrypoint.sh"]