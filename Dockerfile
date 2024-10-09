FROM webdevops/go-crond:main-alpine
LABEL maintainer="Jdavid77 <johnynobrega17@gmail.com>"
ENV DEBIAN_FRONTEND noninteractive

RUN apk --no-cache add \
        curl \
        ca-certificates \
        openssl \
        postgresql-client \
        unzip \
        bash \
        aws-cli

ENV POSTGRES_DATABASE **None**
ENV POSTGRES_BACKUP_ALL **None**
ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''
ENV S3_ACCESS_KEY_ID **None**
ENV S3_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_REGION us-west-1
ENV S3_PATH 'backup'
ENV S3_ENDPOINT **None**
ENV S3_S3V4 no
ENV SCHEDULE **None**
ENV ENCRYPTION_PASSWORD **None**
ENV REMOVE_BEFORE ''

ADD run.sh /scripts/run.sh
ADD backup.sh /scripts/backup.sh


ENTRYPOINT []
CMD ["sh", "/scripts/run.sh"]
