#!/usr/bin/env bash
set -o errexit

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

printf "${BLUE}CRON: ${CRON}\n"
printf "${BLUE}DOMAIN: ${DOMAIN}\n"
printf "${BLUE}EMAIL: ${EMAIL}\n"
printf "${BLUE}PROPAGATION: ${PROPAGATION}\n"
printf "${BLUE}ACME_SERVER: ${ACME_SERVER}\n"
printf "${BLUE}MODE: ${MODE}\n"
printf "${BLUE}NGINX_CONTAINER_NAME: ${NGINX_CONTAINER_NAME}\n"
printf "${NC}-----\n"

# Consider not automatically adding wildcards
printf "${BLUE}Preparing domain-parameters...${NC}\n"
case "${DOMAIN}" in
  *,*)
    IFS=',' read -r -a domainlist <<< "${DOMAIN}"
    DOMAIN=${domainlist[0]}
    for i in "${!domainlist[@]}"; do
      DOMAINS="${DOMAINS} -d ${domainlist[i]} -d *.${domainlist[i]}"
    done
    ;;
  *)
    DOMAINS="-d ${DOMAIN} -d *.${DOMAIN}"
    ;;
esac

printf "${BLUE}Setting staging parameters..."
if test "${MODE}" = "staging"; then
  printf "${GREEN}staging"
  ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
  ARGS="--dry-run"
fi
printf "${NC}\n"

printf "${BLUE}Writing credentials...${NC}\n"
#echo "dns_cloudflare_email = $CLOUDFLARE_EMAIL" >> /cloudflare-credentials.ini
#echo "dns_cloudflare_api_key = $CLOUDFLARE_TOKEN" >> /cloudflare-credentials.ini
printf "dns_cloudflare_api_token = ${CLOUDFLARE_TOKEN}\n" > /cloudflare-credentials.ini
chmod 600 /cloudflare-credentials.ini

printf "${BLUE}Running certbot...${NC}\n"
CERTBOT_COMMAND="certbot certonly ${ARGS} \
  --agree-tos \
  --non-interactive \
  --email ${EMAIL} \
  --server ${ACME_SERVER} \
  --dns-cloudflare \
  --dns-cloudflare-credentials /cloudflare-credentials.ini \
  ${DOMAINS} \
  --dns-cloudflare-propagation-seconds ${PROPAGATION}"

if test -n "${DISCORD_WEBHOOK}"; then
  (set +e; ${CERTBOT_COMMAND} &> /certbot.log) || printf "${RED}Certbot failed, see logs for more info...${NC}\n"
  cat /certbot.log
else
  (set +e; ${CERTBOT_COMMAND}) || printf "${RED}Certbot failed, see logs for more info...${NC}\n"
fi

json_escape () {
  printf '%s' "\`\`\`${1}\`\`\`" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

if test -n "${DISCORD_WEBHOOK}"; then
  printf "${BLUE}Sending Discord notification...${NC}\n"

  CERTBOT_LOG="$(json_escape "$(cat ./certbot.log)")"
  curl --include --silent \
    --request POST \
    --header "Accept: application/json" \
    --header "Content-Type:application/json" \
    --data "{\"username\": \"certbot\", \
             \"avatar_url\": \"https://letsencrypt.org/images/le-logo-twitter-noalpha.png\", \
             \"embeds\": [ \
                { \"title\": \"Certbot Logs\", \"color\": \"3172760\", \"description\": ${CERTBOT_LOG:-"No logs."} } \
              ] \
            }" \
  "${DISCORD_WEBHOOK}"

  printf "\n"
fi
if test -n "${SLACK_WEBHOOK}"; then
  printf "${BLUE}Sending Skack notification...${NC}\n"

  USER_NAME="${DOMAIN} certbot"
  CERTBOT_LOG="$(json_escape "$(cat ./certbot.log)")"
  #CERTBOT_LOG=$(sed 's/"/\\"/g' /certbot.log)
  SLACK_TEXT='Certbot has updated your SSL Certification'
  SLACK_TEXT="${SLACK_TEXT}\n\`\`\`\n${CERTBOT_LOG}\n\`\`\`"

  curl --include --silent \
    --request POST \
    --data-urlencode "payload={ \
                        \"channel\": \"${SLACK_WEBHOOK_CHANNEL}\", \
                        \"username\": \"${USER_NAME}\", \
                        \"text\": \"${SLACK_TEXT}\" \
                      }" \
  "${SLACK_WEBHOOK}"

  printf "\n"
fi

if test -n "${NGINX_CONTAINER_NAME}"; then
  printf "${BLUE}Reloading nginx in the '${NGINX_CONTAINER_NAME}' container...${NC}\n"
  docker exec ${NGINX_CONTAINER_NAME} nginx -s reload
fi

# Maybe crontab actually should just be the entire CERTBOT_COMMAND?
# https://serverfault.com/questions/879647/renew-domains-using-certbot-and-using-dns-challenge
printf "${BLUE}Creating crontab file...${NC}\n"
printf "certbot renew >> /var/log/cron.log 2>&1)\n# Empty line.\n" \
  > /etc/cron.d/crontab

printf "${BLUE}Enabling crontab...${NC}\n"
crontab /etc/cron.d/crontab

# cron? alpine? help!
printf "${BLUE}Starting crond...${NC}\n"
crond
tail -f /var/log/cron.log
