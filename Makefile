.PHONY: bootstrap-dev sync collections bootstrap-host test test-failover converge verify destroy destroy-failover lab-up lab-down lint site-lab

UV ?= uv
VENV ?= .venv
# Desktop login user for SSH/Ansible (override: make bootstrap-host ANSIBLE_USER=other)
ANSIBLE_USER ?= $(shell id -un)

# Prefer project venv binaries; fall back through uv run
export PATH := $(CURDIR)/$(VENV)/bin:$(PATH)
# Keep Ansible configuration, cache, and collection resolution local to this repository.
export ANSIBLE_CONFIG := $(CURDIR)/ansible.cfg
export ANSIBLE_HOME := $(CURDIR)/.ansible
export ANSIBLE_COLLECTIONS_PATH := $(CURDIR)/collections

# molecule-vagrant ships a local Ansible module; Molecule 25+ does not inject it
SITE_PACKAGES := $(shell $(UV) run python -c 'import sysconfig; print(sysconfig.get_path("purelib"))' 2>/dev/null)
export ANSIBLE_LIBRARY := $(SITE_PACKAGES)/molecule_vagrant/modules

bootstrap-dev: sync collections

sync:
	$(UV) python install 3.12
	$(UV) sync --python 3.12
	@echo "Python: $$($(UV) run python -V)"
	@echo "Ansible: $$($(UV) run ansible --version | head -1)"

collections:
	$(UV) run ansible-galaxy collection install -r requirements.yml -p collections

bootstrap-host:
	$(UV) run ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap_host.yml -K \
	  -e ansible_user=$(ANSIBLE_USER)

lint:
	# Rule config and known-warning list live in .ansible-lint
	$(UV) run yamllint playbooks roles molecule inventory group_vars vars
	$(UV) run ansible-lint --project-dir $(CURDIR) playbooks roles molecule

test:
	$(UV) run molecule test -s default

test-failover:
	$(UV) run molecule test -s failover

converge:
	$(UV) run molecule converge -s default

verify:
	$(UV) run molecule verify -s default

destroy:
	$(UV) run molecule destroy -s default

destroy-failover:
	$(UV) run molecule destroy -s failover

lab-up:
	vagrant up --provider=libvirt

lab-down:
	vagrant destroy -f

site-lab:
	$(UV) run ansible-playbook -i inventory/lab.yml playbooks/site.yml
