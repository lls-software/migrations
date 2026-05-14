# shellcheck shell=bash
lambda_enabled() {
  [[ -n ${LAMBDA_ARN-} ]]
}

lambda_require_deps() {
  command -v jq >/dev/null  || die "jq is required for --lambda-arn mode (install: brew install jq | apt-get install jq)"
  command -v aws >/dev/null || die "aws CLI is required for --lambda-arn mode (install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)"
}

lambda_payload_simple() {
  local method=$1 dburl=$2
  jq -nc \
    --arg method "$method" \
    --arg dburl "$dburl" \
    '{jsonrpc: "2.0", id: 1, method: $method, params: {dburl: $dburl}}'
}

lambda_payload_with_file() {
  local method=$1 dburl=$2 filename=$3 file=$4
  jq -nc \
    --arg method "$method" \
    --arg dburl "$dburl" \
    --arg filename "$filename" \
    --rawfile content "$file" \
    '{jsonrpc: "2.0", id: 1, method: $method, params: {dburl: $dburl, filename: $filename, content: $content}}'
}

lambda_payload_unmark() {
  local dburl=$1 filename=$2
  jq -nc \
    --arg dburl "$dburl" \
    --arg filename "$filename" \
    '{jsonrpc: "2.0", id: 1, method: "unmark", params: {dburl: $dburl, filename: $filename}}'
}

lambda_invoke() {
  local payload=$1 outfile metafile rc failed=
  outfile=$(mktemp)
  metafile=$(mktemp)

  aws lambda invoke \
    --function-name "$LAMBDA_ARN" \
    --cli-binary-format raw-in-base64-out \
    --payload "$payload" \
    "$outfile" \
    >"$metafile"
  rc=$?

  cat "$outfile"

  if (( rc != 0 )) || grep -q '"FunctionError"' "$metafile"; then
    failed=1
  fi
  rm -f "$outfile" "$metafile"
  [[ -z $failed ]]
}
