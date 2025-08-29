FROM elixir:1.16.3-otp-25

RUN apt-get update && apt-get install -qq -y --fix-missing --no-install-recommends apt-transport-https curl wget git gcc make libtool-bin file software-properties-common

ENV REPLACE_OS_VARS=true \
  APP_NAME=pubsub \
  MIX_ENV=prod \
  PORT=8080

WORKDIR /opt/app

RUN mkdir -p /opt/app/temp

COPY build/. /opt/release
COPY deploy ./deploy

RUN mv /opt/release/$APP_NAME/bin/$APP_NAME /opt/release/$APP_NAME/bin/start_server

RUN chmod +x /opt/app/deploy/run-server.sh
EXPOSE 8080
ENTRYPOINT ["/opt/app/deploy/run-server.sh"]
