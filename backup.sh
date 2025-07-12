#! /bin/sh

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ] && [ "${POSTGRES_BACKUP_ALL}" != "true" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

# Validate S3_REGION
if [ "${S3_REGION}" = "**None**" ] || [ -z "${S3_REGION}" ]; then
  echo "You need to set the S3_REGION environment variable."
  exit 1
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

# Validate AWS credentials are properly set
if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ] || [ -z "${AWS_DEFAULT_REGION}" ]; then
  echo "AWS credentials not properly configured."
  exit 1
fi

# Set S3 endpoint args for proper command syntax
if [ "${S3_ENDPOINT}" = "**None**" ]; then
  S3_ENDPOINT_ARG=""
else
  S3_ENDPOINT_ARG="--endpoint-url ${S3_ENDPOINT}"
fi

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

# Construct S3 prefix correctly - no leading/trailing slashes issues
if [ -z ${S3_PREFIX+x} ]; then
  S3_PREFIX=""
else
  S3_PREFIX="${S3_PREFIX%/}/"  # Remove trailing slash if present, then add one
fi

if [ "${POSTGRES_BACKUP_ALL}" = "true" ]; then
  SRC_FILE=/tmp/dump.sql.gz
  DEST_FILE=all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

  echo "Creating dump of all databases from ${POSTGRES_HOST}..."
  pg_dumpall -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER | gzip > $SRC_FILE

  if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
    echo "Encrypting ${SRC_FILE}"
    openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
    if [ $? != 0 ]; then
      >&2 echo "Error encrypting ${SRC_FILE}"
    fi
    rm $SRC_FILE
    SRC_FILE="${SRC_FILE}.enc"
    DEST_FILE="${DEST_FILE}.enc"
  fi

  echo "Uploading dump to $S3_BUCKET"
  if [ -z "$S3_PREFIX" ]; then
    cat $SRC_FILE | aws s3 cp - "s3://${S3_BUCKET}/${DEST_FILE}" $S3_ENDPOINT_ARG || exit 2
  else
    cat $SRC_FILE | aws s3 cp - "s3://${S3_BUCKET}/${S3_PREFIX}${DEST_FILE}" $S3_ENDPOINT_ARG || exit 2
  fi

  echo "SQL backup uploaded successfully"
  rm -rf $SRC_FILE
else
  OIFS="$IFS"
  IFS=','
  for DB in $POSTGRES_DATABASE
  do
    IFS="$OIFS"

    SRC_FILE=/tmp/dump.sql.gz
    DEST_FILE=${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dump $POSTGRES_HOST_OPTS $DB | gzip > $SRC_FILE

    if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
      echo "Encrypting ${SRC_FILE}"
      openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
      if [ $? != 0 ]; then
        >&2 echo "Error encrypting ${SRC_FILE}"
      fi
      rm $SRC_FILE
      SRC_FILE="${SRC_FILE}.enc"
      DEST_FILE="${DEST_FILE}.enc"
    fi

    echo "Uploading dump to $S3_BUCKET"
    if [ -z "$S3_PREFIX" ]; then
      cat $SRC_FILE | aws s3 cp - "s3://${S3_BUCKET}/${DEST_FILE}" $S3_ENDPOINT_ARG || exit 2
    else
      cat $SRC_FILE | aws s3 cp - "s3://${S3_BUCKET}/${S3_PREFIX}${DEST_FILE}" $S3_ENDPOINT_ARG || exit 2
    fi

    echo "SQL backup uploaded successfully"
    rm -rf $SRC_FILE
  done
fi
if [ -n "$REMOVE_BEFORE" ]; then
  # Calculate the cutoff date (using coreutils date command)
  date_from_remove=$(date -d "${REMOVE_BEFORE} days ago" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET (older than ${date_from_remove})..."
  if [ -z "$S3_PREFIX" ]; then
        # No prefix - list all objects in bucket
        aws s3api list-objects \
          --bucket "${S3_BUCKET}" \
          --query "${backups_query}" \
          --output text \
          $S3_ENDPOINT_ARG \
          | xargs -n1 -t -I 'KEY' aws s3 rm s3://${S3_BUCKET}/KEY $S3_ENDPOINT_ARG
  else
        # Use prefix to limit scope
        aws s3api list-objects \
          --bucket "${S3_BUCKET}" \
          --prefix "${S3_PREFIX}" \
          --query "${backups_query}" \
          --output text \
          $S3_ENDPOINT_ARG \
          | xargs -n1 -t -I 'KEY' aws s3 rm s3://${S3_BUCKET}/KEY $S3_ENDPOINT_ARG
  fi

  echo "Removal complete."
fi
