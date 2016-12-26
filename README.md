# CentOS-7 Minimal Base Box

This provides the configuration and Makefile to build a [Vagrant](https://www.vagrantup.com) minimal base box using [Packer](https://www.packer.io). The base box is intended for server (terminal) use only so is restricted to a single locale (with `en_US` being the default) which allows for a smaller box size.

There are templates provided for `CentOS-7.2.1511` and `CentOS-7.3.1611` with `x86_64` architecture. There is currently no requirement to support older minor release versions or alternative architectures but they could be added if necessary.

## Usage Instructions

### Prerequisites

The build environment required is Mac OSX or GNU Linux.

To build the box file you will need the following installed:

- [VirtualBox](https://www.virtualbox.org) (5.0.30)
- [Vagrant](https://www.vagrantup.com) (1.9.1)
- [Packer](https://www.packer.io) (0.12.1)

### Build

To build the latest `7.3.1611`, `x86_64` base box run `make` or `make build`.

```
$ make
```

To build the `7.2.1511` release version, use the `BOX_VERSION_RELEASE` environment variable.

```
$ BOX_VERSION_RELEASE=7.2.1511 make
```

#### Box Variants

To build a box variant from an alternative box template use `BOX_VARIANT`. The default is `Minimal` but there is an alternative `Minimal-Cloud-Init` template to build boxes that include Cloud-Init.

```
$ BOX_VARIANT=Minimal-Cloud-Init make
```

### Local install

To install from a box file, generated by a successful build, use `make install` supplied with the same environment variables used to build the require box. This will add the box and output a minimal Vagrantfile template that can be used to create a Vagrantfile in a suitable directory for testing.

```
$ BOX_VARIANT=Minimal-Cloud-Init make install
```
