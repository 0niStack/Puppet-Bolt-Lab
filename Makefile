# Puppet Bolt Lab - Makefile

SHELL := /bin/bash
-include .env
export

.DEFAULT_GOAL := help

.PHONY: help install-bolt check check-agents ping noop-nginx apply-nginx 
        noop-apache apply-apache noop-all apply-all test drift inventory 
        validate clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

install-bolt: ## Install Puppet Bolt on this workstation
	@set -e; 
	if [ -f /etc/os-release ]; then 
		. /etc/os-release; 
		CODENAME="$${VERSION_CODENAME:-}"; 
	else 
		echo "ERROR: Cannot detect operating system"; exit 1; 
	fi; 
	if [ -z "$$CODENAME" ]; then 
		echo "ERROR: Cannot detect distribution codename"; exit 1; 
	fi; 
	echo "Detected OS codename: $$CODENAME"; 
	wget -q "https://apt.puppet.com/puppet8-release-$$CODENAME.deb" 
		-O /tmp/puppet-release.deb; 
	sudo dpkg -i /tmp/puppet-release.deb; 
	sudo apt-get update; 
	sudo apt-get install -y puppet-bolt; 
	bolt --version

check: ## Verify environment and Bolt installation
	@command -v bolt >/dev/null || { echo "ERROR: Bolt not installed. Run make install-bolt"; exit 1; }
	@test -f .env || { echo "ERROR: .env missing. Run cp .env.example .env"; exit 1; }
	@test -n "$$NGINX_HOST" || { echo "ERROR: NGINX_HOST is missing"; exit 1; }
	@test -n "$$APACHE_HOST" || { echo "ERROR: APACHE_HOST is missing"; exit 1; }
	@test -n "$$SSH_USER" || { echo "ERROR: SSH_USER is missing"; exit 1; }
	@test -n "$$SSH_KEY" || { echo "ERROR: SSH_KEY is missing"; exit 1; }
	@test -r "$$SSH_KEY" || { echo "ERROR: SSH private key not readable: $$SSH_KEY"; exit 1; }
	@echo "OK: nginx=$$NGINX_HOST apache=$$APACHE_HOST user=$$SSH_USER"

inventory: check ## Show resolved Bolt inventory
	bolt inventory show --targets all --detail

ping: check ## Test SSH connectivity to both servers
	bolt command run 'hostname && whoami && uptime' --targets all

check-agents: check ## Verify Puppet Agent and bundled Ruby on both servers
	bolt command run '
		echo "--- Puppet Agent ---"; 
		puppet --version; 
		echo "--- Puppet executable ---"; 
		command -v puppet; 
		echo "--- Puppet Ruby ---"; 
		if [ -x /opt/puppetlabs/puppet/bin/ruby ]; then 
			/opt/puppetlabs/puppet/bin/ruby --version; 
			echo "Puppet bundled Ruby: OK"; 
		else 
			echo "ERROR: Puppet bundled Ruby is missing"; 
			exit 1; 
		fi' --targets all

noop-nginx: check ## Dry run Nginx manifest
	bolt apply manifests/nginx.pp --targets nginx_servers --noop

apply-nginx: check ## Apply Nginx manifest
	bolt apply manifests/nginx.pp --targets nginx_servers

noop-apache: check ## Dry run Apache manifest
	bolt apply manifests/apache.pp --targets apache_servers --noop

apply-apache: check ## Apply Apache manifest
	bolt apply manifests/apache.pp --targets apache_servers

noop-all: noop-nginx noop-apache ## Dry run both servers

apply-all: apply-nginx apply-apache ## Apply both servers

test: check ## Test HTTP responses from both servers
	@echo "--- Nginx ($$NGINX_HOST) ---"
	@curl -sS -m 5 -I "http://$$NGINX_HOST/" || echo "Nginx FAILED"
	@echo ""
	@echo "--- Apache ($$APACHE_HOST) ---"
	@curl -sS -m 5 -I "http://$$APACHE_HOST/" || echo "Apache FAILED"

drift: check ## Introduce configuration drift for testing
	bolt command run 'rm -f /var/www/html/index.html /usr/share/nginx/html/index.html' --targets all

validate: ## Validate Puppet manifests
	@set -e; 
	if command -v puppet >/dev/null 2>&1; then 
		PUPPET=$$(command -v puppet); 
	elif [ -x /opt/puppetlabs/bolt/bin/puppet ]; then 
		PUPPET=/opt/puppetlabs/bolt/bin/puppet; 
	else 
		echo "ERROR: Puppet parser not found"; exit 1; 
	fi; 
	for f in manifests/*.pp; do 
		echo "Validating $$f"; 
		"$$PUPPET" parser validate "$$f"; 
	done

clean: ## Remove Bolt cache files
	rm -rf .modules .plan_cache.json .rerun.json
