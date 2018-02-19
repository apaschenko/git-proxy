#! /bin/bash

# ================= settings =======================

LOG_FILE=${HOME}/git_proxy.log;
LOGGING_ENABLE='Yes' # any non-zero-length string enables logging
REPOSITORIES_BASE_PATH=${HOME}/gits

# ============== end of settings ===================

##
# Usage: 
# 
# On your host (client side):
# 1. Generate your SSH-key pair (if it does not exist)
#
# On the proxy host:
# 1. Make sure the git and openssh-server are installed
# 2. For security reasons, create a separate user for the proxy to work without
#        root privilegions.
# 3. Log in to it. All of the following actions perform from this user.
# 4. Put this script file in any useful place (for example, in the root of
#        the home folder).
# 5. In order for the git proxy to connect to git servers using the ssh 
#    protocol, you should add private keys to the folder ~/.ssh of the
#    git proxy host.
#
# 5. Add to ~/.ssh/authorized_keys a line for your autentification:
#
# command="/path/to/this/script[ <key file name>]", <your ssh public key>
#
# In order for the git proxy to connect to git servers using the ssh 
#    protocol, you should add private keys to the folder ~/.ssh on git proxy
#    host. 
#
# For example, let ~/.ssh/authorized_keys contains follow lines:
#
# ssh-rca AAA...BaNG arthur@schopenhauer
# command="/path/to/script", ssh-rca AAA...WoW john@tolkien
# 
#
# As we can see, two users of this host are described here. Lines (from top)
# to bottom):
# Public key AAA...BaNG (arthur@schopenhauer): this user can 
#    enter this host by ssh, but don't use the git proxy (this script file).
# Public key AAA...WoW (john@tolkien): this user can enter this 
#    host and can use the git proxy. Git proxy will use the default key
#    (usually it is ~/.ssh/id_rca) for connections to the git servers.
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
 

function log() {
  if [[ -n ${LOGGING_ENABLE} ]]; then
    echo "$1: $2" >> ${LOG_FILE}
  fi
}


# logging
echo "Command is: ${SSH_ORIGINAL_COMMAND}" >> "$LOG_FILE";

# git pull/fetch/clone
if [[ "${SSH_ORIGINAL_COMMAND}" =~ git-upload-pack\ .* ]]; then

  # create a dir for the repositories if not exists
  mkdir -p "REPOSITORIES_BASE_PATH"

  # domain-name/http|https|ssh|git[:port]/path-to-repo
  input_URL=$(echo "${SSH_ORIGINAL_COMMAND}" | sed -r "s/[^']*'([^']*)'[^']*/\\1/g; s/^\\///");

  # parce of input_URL
  domain_name="${input_URL%%/*}";
  rest="${input_URL#*/}";
  protocol_and_port="${rest%%/*}";
  protocol=${protocol_and_port%:*};
  port=$(echo "${protocol_and_port}:" | sed -r "s/[^:]*://; s/:$//"); 
  path="${rest#*/}";
  path_without_refspec=$(echo "$path" | sed "s/[#+].*$//");
  top_folder_name=$(echo "${domain_name}.${port}" | sed -r "s/\\.$//");
  local_path=${REPOSITORIES_BASE_PATH}/${top_folder_name}/${path_without_refspec};
  [[ -n ${port} ]] && port=":${port}";
  source_URL="${protocol}://${domain_name}${port}/${path}"

  if [ -d "$local_path" ]; then
    current_dir=$(pwd);
    cd "${local_path}";
    until git pull >/dev/null 2>&1; do log "ERROR: Can't pull ${local_path}" $?; done 
    cd "${current_dir}";
  else
    mkdir -p "$local_path";
    until git clone "${source_URL}" "${local_path}" >/dev/null 2>&1; do log "ERROR: Can't clone ${source_URL} into ${local_path}" $?; done
  fi
  
  stdbuf -i0 -o0 -e0 git-upload-pack "${local_path}";

# any other command
elif [[ -n ${SSH_ORIGINAL_COMMAND} ]]; then
  ${SSH_ORIGINAL_COMMAND};

# missing command: we need start new interactive bash-session
else
  bash;
fi

