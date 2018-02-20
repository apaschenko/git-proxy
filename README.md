# git-proxy
Simple proxying of git repositories on linux-based machines

## Purpose
This solution is intended for the simplest implementation of git repo proxying.
It's used for an unstable / slow network for transparent proxy git repositories.


## Usage
### On your host (client side):
* Generate your SSH-key pair (if it does not exist)

### On the proxy host:
* Make sure the git (version >= 2.3) and openssh-server are installed
* For security reasons, create a separate user for the proxy to work without
  root privilegions.
* Log in to it. All of the following actions perform from this user.
* Put this script file in any useful place (for example, in the root of
  the home folder).
* In order for the git proxy to connect to git servers using the ssh 
  protocol, you should add private keys to the folder ~/.ssh of the
  git proxy host.
  Warning, it is important: you MUST set permissions 400 for the each of 
  keys files:
  `chmod 400 /path/to/key/file`
* Add to `~/.ssh/authorized_keys` a line for your autentification:

  > command="/path/to/this/script", your-ssh-public-key

  In order for the git proxy to connect to git servers using the ssh 
  protocol, you should add a private key to the folder ~/.ssh on git proxy
  host. 

  For example, let `~/.ssh/authorized_keys` contains follow lines:

> ssh-rca AAA...BaNG arthur@schopenhauer
> command="/path/to/this/file", ssh-rca AAA...WoW john@tolkien
> command="/path/to/this/file /path/to/key", ssh-rca AAA...RrU terry@pratchett

 As we can see, three users of this host are described here. Lines (from top)
 to bottom):
  * Public key `AAA...BaNG (arthur@schopenhauer)`: this user can 
    enter this host by ssh, but don't use the git proxy (this script file).
  * Public key `AAA...WoW (john@tolkien)`: this user can enter this 
    host and can use the git proxy. Git proxy will use the default key
    (usually it is `~/.ssh/id_rca`) for ssh connections to the git servers.
  * Public key `AAA...RrU (terry@pratchett)`: this user can enter this 
    host and can use the git proxy. Git proxy will use the `/path/to/key` 
    privacy key for ssh connections to the git servers.


### Return to your host and:
* Create a file `.gitconfig` in the root of your home folder
* For each of the domain and git's protocols (`http`, `https`, `git`, `ssh`) that 
  you plan to proxy, add to this file new url section - specify:

  * protocol to communicate with the proxy (it's "ssh:" always);
  * a name of user which you created on the proxy host, and URL of the proxy host;
  * the original domain (through the slash)
  * the protocol (through the slash) by which the proxy will need to 
    connect to the original servers
  * and below specify these protocol and domain.

  For example:

>        [url "ssh://gitproxy_user@my-git-proxy-host/github.com/ssh"]
>            insteadOf = "ssh://github.com"
>
>        [url "ssh://gitproxy_user@my-git-proxy-host/github.com/http"]
>            insteadOf = "git://github.com"
>
>        [url "ssh://gitproxy_user@my-git-proxy-host/bitbucket.com/https"]
>            insteadOf = "https://bitbucket.com"


