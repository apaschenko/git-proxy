#! /bin/bash

# ================= settings =======================

LOG_FILE=${HOME}/git-proxy.log;

# Possible values: 'Nothing', 'Error', 'Warning', 'Info', 'Debug'
LOGGING_LEVEL='Debug'

REPOSITORIES_BASE_PATH=${HOME}/gits

# ============== end of settings ===================

##
# Usage: 
# 
# On your host (client side):
# 1. Generate your SSH-key pair (if it does not exist)
#
# On the proxy host:
# 1. Make sure the git (version >= 2.3) and openssh-server are installed
# 2. For security reasons, create a separate user for the proxy to work
#    without root privilegions.
# 3. Log in to it. All of the following actions perform from this user.
# 4. Put this script file in any useful place (for example, in the root of
#        the home folder).
# 5. In order for the git proxy to connect to git servers using the ssh 
#    protocol, you should add private keys to the folder ~/.ssh of the
#    git proxy host.
#    Warning, it is important: you MUST set permissions 400 for each of 
#    keys files:
#    chmod 400 /path/to/key/file
#
# 6. Add to ~/.ssh/authorized_keys a line for your autentification:
#
# command="/path/to/this/script", <your ssh public key>
#
# 7. In order for the git proxy to connect to git servers using the ssh 
#    protocol, you should add private keys to the folder ~/.ssh on git proxy
#    host. 
#
# For example, let ~/.ssh/authorized_keys contains follow lines:
#
# ssh-rca AAA...BaNG arthur@schopenhauer
# command="/path/to/this/script", ssh-rca AAA...WoW john@tolkien
# command="/path/to/this/script ", ssh-rca AAA...RrU terry@pratchett
#
# As we can see, three users of this host are described here. Lines (from top)
# to bottom):
# Public key AAA...BaNG (arthur@schopenhauer): this user can 
#    enter this host by ssh, but don't use the git proxy (this script file).
# Public key AAA...WoW (john@tolkien): this user can enter this 
#    host and can use the git proxy. Git proxy will use the default key
#    (usually it is ~/.ssh/id_rca) for connections to the git servers.
# Public key `AAA...RrU (terry@pratchett)`: this user can enter this 
#    host and can use the git proxy. Git proxy will use the `/path/to/key` 
#    privacy key for ssh connections to the git servers.
#
# Return to your host and:
# 2. Create a file .gitconfig in the root of your home folder
# 3. For each of the domain and git's protocols (http, https, git, ssh) that 
#        you plan to proxy, add to this file new url section: specify
#
#        - protocol to communicate with the proxy (it's "ssh:" always);
#        - a name of user which you created on the proxy host, URL of the proxy 
#          host;
#        - the original domain (through the slash)
#        - the protocol (through the slash) by which the proxy will need to 
#          connect to the original servers
#        and below specify these protocol and domain.
#
#        For example:
#
#        [url "ssh://gitproxy_user@my-git-proxy-host/github.com/ssh"]
#            insteadOf = "ssh://github.com"
#
#        [url "ssh://gitproxy_user@my-git-proxy-host/github.com/http"]
#            insteadOf = "git://github.com"
#
#        [url "ssh://gitproxy_user@my-git-proxy-host/bitbucket.com/https"]
#            insteadOf = "https://bitbucket.com"
# 
#

function digital_loglevel() {
 low_case_string=${1,,};

  case "${low_case_string}" in
    debug* )
      echo 1 ;;
    info* )
      echo 2 ;;
    warning* )
      echo 3 ;;
    error* )
      echo 4 ;;
    * )
      echo 5 ;;
  esac
}

function log() {
  input_loglevel=`digital_loglevel $1`;

  if [ "${input_loglevel}" -ge "${preset_loglevel}" ]; then
    echo "$1: $2" >> ${LOG_FILE}
  fi

}

preset_loglevel=`digital_loglevel $LOGGING_LEVEL`;

# logging
echo "Command is: ${SSH_ORIGINAL_COMMAND}" >> "$LOG_FILE";

# git pull/fetch/clone
if [[ "${SSH_ORIGINAL_COMMAND}" =~ git-upload-pack\ .* ]]; then

  # format of input string: 
  # '/domain-name/http|https|ssh|git[:port]/path-to-repo'

  # regexp for remove single quotes and a leading slash
  remove_quotes="s/[^']*'([^']*)'[^']*/\\1/g; s/^\\///";
  input_URL=$(echo "${SSH_ORIGINAL_COMMAND}" | sed -r "${remove_quotes}");

  # parce of input_URL
  domain_name="${input_URL%%/*}";
  rest="${input_URL#*/}";
  protocol_and_port="${rest%%/*}";
  protocol=${protocol_and_port%:*};
  port=$(echo "${protocol_and_port}:" | sed -r "s/[^:]*://; s/:$//"); 
  path="${rest#*/}";
  path_without_refspec=$(echo "$path" | sed "s/[#+].*$//");
  top_folder_name=$(echo "${domain_name}.${port}" | sed -r "s/\\.$//");
  local_path="${REPOSITORIES_BASE_PATH}"
  local_path="${local_path}/${top_folder_name}/${path_without_refspec}";
  [[ -n ${port} ]] && port=":${port}";
  source_URL="${protocol}://${domain_name}${port}/${path}"
  debug_info="input_URL: ${input_URL}, protocol: ${protocol}, port: ${port}"
  debug_info="$debug_info, local_path: $local_path, source_URL: $source_URL"

  log "DEBUG: $debug_info";

  if [ -d "$local_path" ]; then
    current_dir=$(pwd);
    cd "${local_path}";
    
    if ! git fetch --all >/dev/null 2>&1; then
      log "ERROR: Can't fetch ${local_path}" $?;
      exit;
    fi
    
    if ! git pull --all >/dev/null 2>&1; then
      log "ERROR: Can't pull ${local_path}" $?;
      exit;
    fi

    cd "${current_dir}";
  else
    mkdir -p "$local_path";
    current_dir=$(pwd);
    cd "${local_path}";
 
    if ! git clone "${source_URL}" . >/dev/null 2>&1; then
      log "ERROR: Can't clone ${source_URL} into ${local_path}" $?;
      exit;
    fi
    git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*';
    cd "${current_dir}";
  fi

  if [[ $protocol == "ssh" && -n $1 ]]; then
    export GIT_SSH_COMMAND="ssh -i \"${1}\"";
  fi

  stdbuf -i0 -o0 -e0 git-upload-pack "${local_path}";

# any other command
elif [[ -n ${SSH_ORIGINAL_COMMAND} ]]; then
  ${SSH_ORIGINAL_COMMAND};

# missing command: we need start new interactive bash-session
else
  bash;
fi

