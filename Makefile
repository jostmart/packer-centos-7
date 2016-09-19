export SHELL := /usr/bin/env bash
export PATH := ${PATH}

BOX_NAMESPACE := jdeathe
BOX_PROVIDOR := virtualbox
BOX_ARCH_PATTERN := ^(x86_64|i386)$

BOX_ARCH ?= x86_64
BOX_DEBUG ?= false
BOX_LANG ?= en_US
BOX_OUTPUT_PATH ?= ./builds
BOX_VARIANT ?= Minimal
BOX_VERSION_RELEASE ?= 7.2.1511

# UI constants
COLOUR_NEGATIVE := \033[1;31m
COLOUR_POSITIVE := \033[1;32m
COLOUR_RESET := \033[0m
CHARACTER_STEP := ==>
PREFIX_STEP := $(shell \
	printf -- '%s ' \
	"$(CHARACTER_STEP)"; \
)
PREFIX_SUB_STEP := $(shell \
	printf -- ' %s ' \
	"$(CHARACTER_STEP)"; \
)
PREFIX_STEP_NEGATIVE := $(shell \
	printf -- '%b%s%b' \
	"$(COLOUR_NEGATIVE)" \
	"$(PREFIX_STEP)" \
	"$(COLOUR_RESET)"; \
)
PREFIX_STEP_POSITIVE := $(shell \
	printf -- '%b%s%b' \
	"$(COLOUR_POSITIVE)" \
	"$(PREFIX_STEP)" \
	"$(COLOUR_RESET)"; \
)
PREFIX_SUB_STEP_NEGATIVE := $(shell \
	printf -- '%b%s%b' \
	"$(COLOUR_NEGATIVE)" \
	"$(PREFIX_SUB_STEP)" \
	"$(COLOUR_RESET)"; \
)
PREFIX_SUB_STEP_POSITIVE := $(shell \
	printf -- '%b%s%b' \
	"$(COLOUR_POSITIVE)" \
	"$(PREFIX_SUB_STEP)" \
	"$(COLOUR_RESET)"; \
)

.DEFAULT_GOAL := build

# Get absolute file paths
BOX_OUTPUT_PATH := $(realpath $(BOX_OUTPUT_PATH))
BOX_VERSION_PATCH := $(shell \
	awk 'BEGIN { FS="." } { print $$3 }' <<< $(BOX_VERSION_RELEASE); \
)
PACKER_BUILD_NAME := $(shell \
	printf -- 'CentOS-%s-%s-%s-%s' \
		"$(BOX_VERSION_RELEASE)" \
		"$(BOX_ARCH)" \
		"$(BOX_VARIANT)" \
		"$(BOX_LANG)"; \
)
PACKER_TEMPLATE_NAME := $(shell \
	printf -- 'CentOS-7-%s-%s.json' \
		"$(BOX_VARIANT)" \
		"$(BOX_PROVIDOR)"; \
)
PACKER_VAR_FILE := $(shell \
	printf -- 'CentOS-%s-%s-%s-%s.json' \
		"$(BOX_VERSION_RELEASE)" \
		"$(BOX_ARCH)" \
		"$(BOX_VARIANT)" \
		"$(BOX_LANG)"; \
)
SOURCE_ISO_NAME := $(shell \
	printf -- 'CentOS-7-%s-Minimal-%s.iso' \
		"$(BOX_ARCH)" \
		"$(BOX_VERSION_PATCH)"; \
)

# Package prerequisites
curl := $(shell type -p curl)
gzip := $(shell type -p gzip)
openssl := $(shell type -p openssl)
packer := $(shell type -p packer)
vagrant := $(shell type -p vagrant)
vboxmanage := $(shell type -p vboxmanage)

.PHONY: \
	all \
	build \
	install \
	prerequisites \
	require-supported-architecture

all: prerequisites | build

build: prerequisites require-supported-architecture download-iso
	@ echo "$(PREFIX_STEP)Building $(PACKER_BUILD_NAME)"
	@ if [[ ! -f $(PACKER_VAR_FILE) ]]; then \
			echo "$(PREFIX_SUB_STEP_NEGATIVE)Missing var-file: $(PACKER_VAR_FILE)" >&2; \
			exit 1; \
		elif [[ ! -f $(PACKER_TEMPLATE_NAME) ]]; then \
			echo "$(PREFIX_SUB_STEP_NEGATIVE)Missing template: $(PACKER_TEMPLATE_NAME)" >&2; \
			exit 1; \
		else \
			if [[ $(BOX_DEBUG) == true ]]; then \
				$(packer) build \
					-debug \
					-force \
					-var-file=$(PACKER_VAR_FILE) \
					$(PACKER_TEMPLATE_NAME); \
			else \
				$(packer) build \
					-force \
					-var-file=$(PACKER_VAR_FILE) \
					$(PACKER_TEMPLATE_NAME); \
			fi; \
			if [[ $${?} -eq 0 ]]; then \
				$(openssl) sha1 \
					$(BOX_OUTPUT_PATH)/$(PACKER_BUILD_NAME)-$(BOX_PROVIDOR).box \
					| awk '{ print $$2; }' \
					> $(BOX_OUTPUT_PATH)/$(PACKER_BUILD_NAME)-$(BOX_PROVIDOR).box.sha1; \
				echo "$(PREFIX_SUB_STEP_POSITIVE)Build complete"; \
			else \
				rm -f $(BOX_OUTPUT_PATH)/$(PACKER_BUILD_NAME)-$(BOX_PROVIDOR).box.sha1 &> /dev/null; \
				echo "$(PREFIX_SUB_STEP_NEGATIVE)Build error" >&2; \
				exit 1; \
			fi; \
		fi

download-iso: prerequisites require-supported-architecture
	@ if [[ ! -f isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME) ]]; then \
			if [[ ! -d ./isos/$(BOX_ARCH) ]]; then \
				mkdir -p ./isos/$(BOX_ARCH); \
			fi; \
			echo "$(PREFIX_STEP)Downloading ISO: http://mirrors.kernel.org/centos/$(BOX_VERSION_RELEASE)/isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME)"; \
			$(curl) -LSo ./isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME) \
				http://mirrors.kernel.org/centos/$(BOX_VERSION_RELEASE)/isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME); \
			if [[ $${?} -eq 0 ]]; then \
				rm -f ./isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME) &> /dev/null; \
				echo "$(PREFIX_STEP)Download failed - trying vault: http://archive.kernel.org/centos-vault/$(BOX_VERSION_RELEASE)/isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME)"; \
				$(curl) -LSo ./isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME) \
					http://archive.kernel.org/centos-vault/$(BOX_VERSION_RELEASE)/isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME); \
			fi; \
			if [[ $${?} -eq 0 ]]; then \
				echo "$(PREFIX_STEP_NEGATIVE)ISO Download failed" >&2; \
				rm -f ./isos/$(BOX_ARCH)/$(SOURCE_ISO_NAME) &> /dev/null; \
				exit 1; \
			fi; \
		fi

install: prerequisites require-supported-architecture
	$(eval $@_box_name := $(shell \
		echo "$(PACKER_BUILD_NAME)" \
			| awk '{ print tolower($$1); }' \
	))
	$(eval $@_box_checksum := $(shell \
		$(openssl) sha1 \
			$(BOX_OUTPUT_PATH)/$(PACKER_BUILD_NAME)-$(BOX_PROVIDOR).box \
			| awk '{ print $$2; }' \
	))
	$(eval $@_box_hash := $(shell \
		echo "$($@_box_checksum)" \
			| cut -c1-8 \
	))
	@ if [[ -f $(BOX_OUTPUT_PATH)/$(PACKER_BUILD_NAME)-$(BOX_PROVIDOR).box ]]; then \
			echo "$(PREFIX_STEP)Installing $(BOX_NAMESPACE)/$($@_box_name)/$($@_box_hash)"; \
			$(vagrant) box add --force \
				--name $(BOX_NAMESPACE)/$($@_box_name)/$($@_box_hash) \
				$(BOX_OUTPUT_PATH)/$(PACKER_BUILD_NAME)-$(BOX_PROVIDOR).box; \
			echo "$(PREFIX_STEP)Vagrantfile:"; \
			$(vagrant) init --output - --minimal $(BOX_NAMESPACE)/$($@_box_name)/$($@_box_hash); \
		else \
			echo "$(PREFIX_STEP_NEGATIVE)No box file."; \
			echo "$(PREFIX_SUB_STEP)Try running: make build"; \
		fi

prerequisites:
ifeq ($(vboxmanage),)
	$(error "Please install VirtualBox. (https://www.virtualbox.org/)")
endif

ifeq ($(vagrant),)
	$(error "Please install Vagrant. (https://www.vagrantup.com)")
endif

ifeq ($(packer),)
	$(error "Please install Packer. (https://www.packer.io)")
endif

ifeq ($(curl),)
	$(error "Please install the curl package.")
endif

ifeq ($(gzip),)
	$(error "Please install the gzip package.")
endif

ifeq ($(openssl),)
	$(error "Please install the openssl package.")
endif

require-supported-architecture:
	@ if [[ ! $(BOX_ARCH) =~ $(BOX_ARCH_PATTERN) ]]; then \
			echo "$(PREFIX_STEP_NEGATIVE)Unsupported architecture ($(BOX_ARCH))" >&2; \
			echo "$(PREFIX_SUB_STEP)Supported values: x86_64|i386." >&2; \
			exit 1; \
		fi
