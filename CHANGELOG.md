## v0.7.0

* General clean up, per Foodcritic compliance
* Fix several minor platform bugs on RedHat/CentOS
* Change service assumptions regarding Redhat/Centos
* Added several missing dependencies
* Fenced off debian/ubuntu specific cases in case switches 
* Changed sshkey generation to use pure Ruby via gem, instead of execute.
* Made basic auth optional in proxy_apache2, as Jenkins comes with several of its own auth plugins
