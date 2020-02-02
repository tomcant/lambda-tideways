#!/usr/bin/env bash

PHP_VERSIONS=(72 73 74)
TIDEWAYS_VERSION=5.0.58
AWS_CLI=aws2
AWS_REGION=eu-west-1

set -e

ROOT=$(pwd)

for PHP_VERSION in ${PHP_VERSIONS[@]}; do
  echo ""
  echo "### Building Tideways $TIDEWAYS_VERSION for PHP $PHP_VERSION"
  echo ""
  docker build -f Dockerfile.agent -t tideways-$TIDEWAYS_VERSION-php-$PHP_VERSION --build-arg PHP_VERSION=$PHP_VERSION --build-arg TIDEWAYS_VERSION=$TIDEWAYS_VERSION .
  mkdir -p export/tmp && rm -fr export/tmp/* && cd export/tmp
  docker run --entrypoint "tar" tideways-$TIDEWAYS_VERSION-php-$PHP_VERSION -ch -C /opt . | tar -x
  zip --quiet -X --recurse-paths ../`echo "tideways-$TIDEWAYS_VERSION-php-$PHP_VERSION"`.zip .
  cd $ROOT && rm -fr export/tmp
done

for PHP_VERSION in ${PHP_VERSIONS[@]}; do
  echo ""
  echo "### Publishing Tideways $TIDEWAYS_VERSION for PHP $PHP_VERSION"
  echo ""
  LAYER_VERSION=$($AWS_CLI lambda publish-layer-version \
    --region $AWS_REGION \
    --layer-name tideways-php-$PHP_VERSION \
    --description tideways-$TIDEWAYS_VERSION-php-$PHP_VERSION \
    --license-info MIT \
    --zip-file fileb://export/tideways-$TIDEWAYS_VERSION-php-$PHP_VERSION.zip \
    --compatible-runtimes provided \
    --output text \
    --query Version)
  $AWS_CLI lambda add-layer-version-permission \
    --region $AWS_REGION \
    --layer-name tideways-php-$PHP_VERSION \
    --version-number $LAYER_VERSION \
    --statement-id public \
    --action lambda:GetLayerVersion \
    --principal "*"
done
