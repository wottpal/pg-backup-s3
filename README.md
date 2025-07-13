# pg-backup-s3
A docker image to back up Postgres into the S3-compatible storage.

This repo is a fork of [Jdavid77/pg-backup-s3](https://github.com/Jdavid77/pg-backup-s3/blob/main/Dockerfile) which itself is a fork of [ariaieboy/pg-backup-s3](https://github.com/ariaieboy/pg-backup-s3). Full credit to the authors.

## Usage

Docker:
```sh
$ docker run -e S3_ACCESS_KEY_ID=key -e S3_SECRET_ACCESS_KEY=secret -e S3_BUCKET=my-bucket -e S3_PREFIX=backup -e POSTGRES_DATABASE=dbname -e POSTGRES_USER=user -e POSTGRES_PASSWORD=password -e POSTGRES_HOST=localhost ariaieboy/pg-backup-s3
```

Docker Compose:
```yaml
postgres:
  image: postgres
  environment:
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password

pgbackups3:
  image: ghcr.io/jdavid77/pg-backup-s3:main
  depends_on:
    - postgres
  links:
    - postgres
  environment:
    REMOVE_BEFORE: 30 # optional, to auto-delete backups older than 30 days
    SCHEDULE: '@daily' # leave blank or provide "**None**" to disable automatic backups
    S3_REGION: region # use "auto" to automatically detect the region
    S3_ACCESS_KEY_ID: key
    S3_SECRET_ACCESS_KEY: secret
    S3_BUCKET: my-bucket
    S3_PREFIX: backup
    POSTGRES_BACKUP_ALL: "false" # set to "true" to backup all databases
    POSTGRES_HOST: host
    POSTGRES_DATABASE: dbname
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password
    POSTGRES_EXTRA_OPTS: '--schema=public --blobs' # remove '--schema=public' if you want to backup all schemas
```

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

### Backup All Databases

You can backup all available databases by setting `POSTGRES_BACKUP_ALL="true"`.

Single archive with the name `all_<timestamp>.sql.gz` will be uploaded to S3

### Endpoints for S3

An Endpoint is the URL of the entry point for an AWS web service or S3 Compitable Storage Provider.

You can specify an alternate endpoint by setting `S3_ENDPOINT` environment variable like `protocol://endpoint`

**Note:** S3 Compitable Storage Provider requires `S3_ENDPOINT` environment variable

## Automatic Cleanup

You can remove old backups by setting the `REMOVE_BEFORE` environment for example if you pass 30 it will remove files older than 30 days old.

### Encryption

You can additionally set the `ENCRYPTION_PASSWORD` environment variable like `-e ENCRYPTION_PASSWORD="superstrongpassword"` to encrypt the backup. It can be decrypted using `openssl aes-256-cbc -d -in backup.sql.gz.enc -out backup.sql.gz`.


## Testing the Database Locally

### Quick Local Testing with Docker

1. **Start PostgreSQL 17 container**
```bash
docker run --name temp-postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=testdb \
  -d -p 5432:5432 \
  postgres:17
```

2. **Download the database dump from S3**

3. **Restore your database from the dump**
```bash
gunzip -c your_dump.sql.gz | docker exec -i temp-postgres psql -U postgres -d testdb
```

1. **Connect and explore**
```bash
# Via command line
docker exec -it temp-postgres psql -U postgres -d testdb

# Or use any PostgreSQL GUI with these connection details:
# Host: localhost
# Port: 5432
# Database: testdb
# Username: postgres
# Password: password
```

2. **Clean up when finished**
```bash
docker stop temp-postgres && docker rm temp-postgres
```

