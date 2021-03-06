#!/bin/bash

function sha256UrlSafe  {
  # $1 | tr '+' '-' | tr '/' '_'
  echo $(openssl dgst -sha256 -binary $1 | base64 | tr '+' '-' | tr '/' '_')
}

#
# creates order subdirectory and copies in raw-order as order.json
#
function createOrderSubdirectoryWithOrder {
  mkdir downloadable-collection/$1
  cp $2 downloadable-collection/$1/order
}

#
# Given our global timing variables, fill in the template, write it to a tmp file
#
function createOrderFromTemplate {
  source $1
  baseName=$(basename `pwd`/raw-orders/$1 .sh)
  orderJson=raw-orders/$baseName.json
  echo $ORDER > $orderJson
}


#
# computes retailer signature over raw order bytes
#
function writeRetailerSignature {
  RETAILER_SIG_BASE64=$(openssl dgst -sha256 -binary -sign retailer/retailer-private_key.pem downloadable-collection/$1/order | base64)

  RETAILER_SIGN_JSON=$(cat <<EOF
{
  "algorithm": "rsa-sha256",
  "keyId": "retailer1",
  "signature": "$RETAILER_SIG_BASE64"
}
EOF
)
  echo $RETAILER_SIGN_JSON > downloadable-collection/$1/order.signature
}

#
# writes operator acceptance document for order
#
function writeOperatorAcceptance {
  RETAILER_ORDER_REFERENCE=$(jq '.metadata."retailer-order-reference"' -r downloadable-collection/$1/order)
  ORDER_ACCEPTANCE=$(cat <<EOF
{
  "order-digest": "sha256:$1",
  "retailer-order-reference": "$RETAILER_ORDER_REFERENCE",
  "retailer": {
    "href": "http://www.operator.com/entities/retailer"
  },
  "order-processing-result": "accepted"
}
EOF
)
  echo $ORDER_ACCEPTANCE > downloadable-collection/$1/order.result
}

#
# operator signs the order.result acceptance document
#
function writeOperatorSignature {
  openssl dgst -sha256 -binary \
    -sign operator/operator-private_key.pem \
    -out downloadable-collection/$1/order.result.signature.raw \
    downloadable-collection/$1/order.result

  OPERATOR_SIG_BASE64=$(cat downloadable-collection/$1/order.result.signature.raw | base64)
  OPERATOR_SIGN_JSON=$(cat <<EOF
{
  "algorithm": "rsa-sha256",
  "keyId": "operator1",
  "signature": "$OPERATOR_SIG_BASE64"
}
EOF
)
  echo $OPERATOR_SIGN_JSON > downloadable-collection/$1/order.result.signature
}

function timestampOperatorSignature {
  openssl ts -query -sha256 -cert \
    -data downloadable-collection/$1/order.result.signature.raw \
    -out downloadable-collection/$1/order.result.signature.tsq

  openssl ts -config openssl.cnf -reply \
    -queryfile downloadable-collection/$1/order.result.signature.tsq \
    -signer tsa/tsa-cert.pem \
    -inkey tsa/tsa-private_key.pem \
    -chain ca/certs/ca-cert.pem \
    -out downloadable-collection/$1/order.result.signature.timestamp.raw

  openssl ts -verify \
    -queryfile downloadable-collection/$1/order.result.signature.tsq \
    -in downloadable-collection/$1/order.result.signature.timestamp.raw \
    -CAfile ca/certs/ca-cert.pem

  cat downloadable-collection/$1/order.result.signature.timestamp.raw | base64 > downloadable-collection/$1/order.result.signature.timestamp

  #remove unnecessary working arefacts
  rm downloadable-collection/$1/order.result.signature.tsq
  rm downloadable-collection/$1/order.result.signature.raw
  rm downloadable-collection/$1/order.result.signature.timestamp.raw
}

function before {
  #
  # clean up any left over downloadable-collection
  #
  if [ -d downloadable-collection ]; then
    echo "removing existing downloadable-collection in $(pwd)/downloadable-collection"
    rm -rf downloadable-collection
  fi
  mkdir downloadable-collection

  #
  # clean up any template output from raw-orders
  #
  rm -rf raw-orders/*.json

  if [ -e downloadable-collection.zip ]; then
    rm downloadable-collection.zip
  fi
}

#
# set timezone in the shell to UTC,
# remember the original one
#
TZ_ORIG=$TZ
TZ="/usr/share/zoneinfo/UTC"
export TZ

# timings for use in the order "templates"
NOW=$(date +%Y-%m-%dT%H:%M:%SZ)
IN_TWO_DAYS=$(date -v "+2d" +%Y-%m-%d)
IN_THREE_DAYS=$(date -v "+3d" +%Y-%m-%d)


before

for order in $(ls raw-orders/*.sh); do
  createOrderFromTemplate $order
  orderSha=`sha256UrlSafe $orderJson`
  createOrderSubdirectoryWithOrder $orderSha $orderJson
  writeRetailerSignature $orderSha
  writeOperatorAcceptance $orderSha
  writeOperatorSignature $orderSha
  timestampOperatorSignature $orderSha
done

# create a zip of downloadable-collection
zip -r  downloadable-collection.zip downloadable-collection/

export TZ=$TZ_ORIG
