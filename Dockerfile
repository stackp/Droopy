FROM python:3-alpine

MAINTAINER Filippo Cremonese (fcremo)

RUN mkdir -p /app/data && mkdir -p /app/config

COPY droopy /app/droopy
COPY config/config /app/config/config

EXPOSE 8000

CMD [ "python", "/app/droopy", "--config-file", "/app/config/config" ]


