-- Create LocalStack S3 secret for wildlife bucket (penguins dataset)
-- This secret allows pg_lake to access s3://${S3_BUCKET} bucket
-- Note: Environment variables are substituted via envsubst before execution

-- Drop existing secret if it exists
DROP SECRET IF EXISTS wildlife_s3_secret;

-- Create S3 secret for LocalStack
CREATE SECRET wildlife_s3_secret (
    TYPE s3,
    SCOPE 's3://${S3_BUCKET}',
    USE_SSL false,
    KEY_ID '${AWS_ACCESS_KEY_ID}',
    SECRET '${AWS_SECRET_ACCESS_KEY}',
    URL_STYLE 'path',
    ENDPOINT '${LOCALSTACK_ENDPOINT}',
    REGION '${AWS_DEFAULT_REGION}'
);

-- Verify the secret was created
SELECT * FROM duckdb_secrets();
