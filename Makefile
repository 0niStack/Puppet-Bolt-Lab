SHELL := /bin/bash
-include .env
export

.DEFAULT_GOAL := help
.PHONY: help install-bolt check ping noop-nginx apply-nginx noop-apache apply-apache noop-all apply-all test drift inventory validate clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install-bolt: ## Install Puppet Bolt on this workstation (Ubuntu/Debian)
	wget -q https://apt.puppet.com/puppet8-release-$$(lsb_release -cs).deb -O /tmp/puppet-release.deb
	sudo dpkg -i /tmp/puppet-release.deb
	sudo apt-get update && sudo apt-get install -y puppet-bolt
	bolt --version

check: ## Verify .env is filled in and Bolt is installed
	@command -v bolt >/dev/null || { echo "bolt not found. Run: make install-bolt"; exit 1; }
	@test -f .env || { echo ".env missing. Run: cp .env.example .env"; exit 1; }
	@test -n "$$NGINX_HOST" -a -n "$$APACHE_HOST" || { echo "Set NGINX_HOST and APACHE_HOST in .env"; exit 1; }
	@echo "OK: nginx=$$NGINX_HOST apache=$$APACHE_HOST user=$$SSH_USER"

inventory: check ## Show resolved inventory
	bolt inventory show --targets all --detail

ping: check ## Test SSH connectivity to both servers
	bolt command run 'uname -n && uptime' --targets all

noop-nginx: check ## Dry run nginx manifest (shows what would change)
	bolt apply manifests/nginx.pp --targets nginx_servers --noop

apply-nginx: check ## Apply nginx manifest to the nginx server
	bolt apply manifests/nginx.pp --targets nginx_servers

noop-apache: check ## Dry run apache manifest
	bolt apply manifests/apache.pp --targets apache_servers --noop

apply-apache: check ## Apply apache manifest to the apache server
	bolt apply manifests/apache.pp --targets apache_servers

noop-all: noop-nginx noop-apache ## Dry run both servers

apply-all: apply-nginx apply-apache ## Apply both servers

test: check ## Curl both servers on port 80
	@echo "--- nginx ($$NGINX_HOST) ---"; curl -s -m 5 http://$$NGINX_HOST/ || echo "FAILED"
	@echo "--- apache ($$APACHE_HOST) ---"; curl -s -m 5 http://$$APACHE_HOST/ || echo "FAILED"

drift: check ## Break index.html on both servers, then run: make apply-all to watch Puppet repair it
	bolt command run 'rm -f /var/www/html/index.html /usr/share/nginx/html/index.html' --targets all

validate: ## Syntax-check the manifests (needs puppet or puppet-bolt installed)
	@for f in manifests/*.pp; do echo "validating $$f"; /opt/puppetlabs/bolt/bin/puppet parser validate $$f 2>/dev/null || puppet parser validate $$f; done

clean: ## Remove Bolt cache files
	rm -rf .modules .plan_cache.json .rerun.json
