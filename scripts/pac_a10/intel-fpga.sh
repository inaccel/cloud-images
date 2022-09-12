#!/bin/sh

[ ${DEBUG} ] && set -vx
set -eu

TMPDIR=$(mktemp --directory --tmpdir=/ inaccel.XXXXXXXXXX)

chmod 0755 ${TMPDIR}

cd ${TMPDIR}

trap "rm -fr ${TMPDIR}" EXIT

################################################################################

# InAccel runtime
INACCEL_FPGA=2.2.3

. /etc/os-release

if [ ${ID} = centos ]; then
	setenforce 0

	yum makecache && yum install -y wget

	# Download Intel FPGA packages
	wget -O- "https://downloads.intel.com/akdlm/software/ias/1.2.1/a10_gx_pac_ias_1_2_1_pv_rte.tar.gz" | tar xz --strip-components 1
	wget -O aocl-pro-rte.run "https://downloads.intel.com/akdlm/software/acdsinst/20.4/72/ib_installers/aocl-pro-rte-20.4.0.72-linux.run" && chmod +x aocl-pro-rte.run

	# Download InAccel runtime
	wget -O inaccel-fpga.rpm "https://dl.cloudsmith.io/public/inaccel/stable/rpm/any-distro/any-version/x86_64/inaccel-fpga-${INACCEL_FPGA}-1.x86_64.rpm"

	VERSION=$(cat /etc/centos-release | cut -d " " -f 4)

	# CentOS Vault
	VAULT=https://vault.centos.org/${VERSION}/updates/x86_64/Packages

	# Install Extra Packages for Enterprise Linux (EPEL)
	yum install -y epel-release

	# Install Kernel Headers (required by Xilinx FPGA packages)
	if ! yum install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r); then
		# Kernel Headers not found, retry using the CentOS Vault
		yum install -y ${VAULT}/kernel-devel-$(uname -r).rpm ${VAULT}/kernel-headers-$(uname -r).rpm
	fi

	# Install Intel FPGA packages
	sed -e "s|more |cat |g" -e "s|yum install|yum install -y|g" -i setup.sh
	yes | ${PWD}/setup.sh --installdir /opt --yes
	${PWD}/aocl-pro-rte.run --accept_eula 1 --installdir /opt/opencl_rte --mode unattended
	echo "@reboot bash /opt/intelrtestack/init_env.sh" | crontab

	# Install InAccel runtime
	if ! yum list installed inaccel-fpga; then
		yum install -y ./inaccel-fpga.rpm
	else
		yum upgrade -y ./inaccel-fpga.rpm
	fi
	sed -e "s|/path/to/host|/opt/opencl_rte/aclrte-linux64/host|" -e "s|/path/to/opencl_bsp|/opt/intelrtestack/a10_gx_pac_ias_1_2_1_pv/opencl/opencl_bsp|" -i /etc/inaccel/runtimes/intel-fpga/inaccel.pc

	setenforce 1
elif [ ${ID} = ubuntu ]; then
	export DEBIAN_FRONTEND=noninteractive

	apt update && apt install -y wget

	# Download Intel FPGA packages
	wget -O- "https://downloads.intel.com/akdlm/software/ias/1.2.1/a10_gx_pac_ias_1_2_1_pv_rte.tar.gz" | tar xz --strip-components 1
	wget -O aocl-pro-rte.run "https://downloads.intel.com/akdlm/software/acdsinst/20.4/72/ib_installers/aocl-pro-rte-20.4.0.72-linux.run" && chmod +x aocl-pro-rte.run

	# Download InAccel runtime
	wget -O inaccel-fpga.deb "https://dl.cloudsmith.io/public/inaccel/stable/deb/any-distro/pool/any-version/main/i/in/inaccel-fpga_${INACCEL_FPGA}/inaccel-fpga_${INACCEL_FPGA}_amd64.deb"

	# Install Intel FPGA packages
	sed -e "s|more |cat |g" -e "s|apt-get install|apt-get install -y|g" -i setup.sh
	yes | ${PWD}/setup.sh --installdir /opt --yes
	${PWD}/aocl-pro-rte.run --accept_eula 1 --installdir /opt/opencl_rte --mode unattended
	echo "@reboot bash /opt/intelrtestack/init_env.sh" | crontab

	# Install InAccel runtime
	apt install -o Dpkg::Options::=--refuse-downgrade -y --allow-downgrades ./inaccel-fpga.deb
	sed -e "s|/path/to/host|/opt/opencl_rte/aclrte-linux64/host|" -e "s|/path/to/opencl_bsp|/opt/intelrtestack/a10_gx_pac_ias_1_2_1_pv/opencl/opencl_bsp|" -i /etc/inaccel/runtimes/intel-fpga/inaccel.pc
fi
