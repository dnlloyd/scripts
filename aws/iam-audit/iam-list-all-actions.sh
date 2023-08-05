curl --header 'Connection: keep-alive' \
    --header 'Pragma: no-cache' \
    --header 'Cache-Control: no-cache' \
    --header 'Accept: */*' \
    --header 'Referer: https://awspolicygen.s3.amazonaws.com/policygen.html' \
    --header 'Accept-Language: en-US,en;q=0.9' \
    --silent \
    --compressed \
    'https://awspolicygen.s3.amazonaws.com/js/policies.js' |
    cut -d= -f2 |
    jq -r '.serviceMap[] | .StringPrefix as $prefix | .Actions[] | "\($prefix):\(.)"' |
    sort |
    uniq
