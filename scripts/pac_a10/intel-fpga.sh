#!/bin/sh

[ ${DEBUG} ] && set -vx
set -eu

TMPDIR=$(mktemp --directory --tmpdir=/ inaccel.XXXXXXXXXX)

chmod 0755 ${TMPDIR}

cd ${TMPDIR}

trap "rm -fr ${TMPDIR}" EXIT

################################################################################

# InAccel runtime
INACCEL_FPGA=2.2.5

. /etc/os-release

if [ ${ID} = ubuntu ]; then
	export DEBIAN_FRONTEND=noninteractive

	apt update
	apt install -y ca-certificates wget

	# Download Intel FPGA packages
	wget -O aocl-pro-rte.run 'https://downloads.intel.com/akdlm/software/acdsinst/20.4/72/ib_installers/aocl-pro-rte-20.4.0.72-linux.run'
	chmod +x aocl-pro-rte.run

	wget -O- 'https://downloads.intel.com/akdlm/software/acdsinst/19.2/57/ib_tar/intel_a10gx_pac.tar.gz' | tar xz --no-same-owner
	chmod o=g -R intel_a10gx_pac
	sed -e 's|sudo udevadm trigger --name /dev/intel-fpga-fme.*|ls -1 /dev/intel-fpga-fme.* \| xargs -i sudo udevadm trigger --name {}|g' -e 's|sudo udevadm trigger --name /dev/intel-fpga-port.*|ls -1 /dev/intel-fpga-port.* \| xargs -i sudo udevadm trigger --name {}|g' -i intel_a10gx_pac/linux64/libexec/setup_permissions.sh

	# Download InAccel runtime
	wget -O inaccel-fpga.deb "https://dl.cloudsmith.io/public/inaccel/stable/deb/any-distro/pool/any-version/main/i/in/inaccel-fpga_${INACCEL_FPGA}/inaccel-fpga_${INACCEL_FPGA}_amd64.deb"

	# Install Linux Extra Modules (required by Intel FPGA packages)
	apt install -y linux-modules-extra-$(uname -r)

	# Install Intel FPGA packages
	mkdir /opt/intelrtestack

	${PWD}/aocl-pro-rte.run --accept_eula 1 --installdir /opt/opencl_rte --mode unattended

	cat << 'EOF' > /opt/intelrtestack/init_env.sh
export INTELFPGAOCLSDKROOT=/opt/opencl_rte/aclrte-linux64
export AOCL_BOARD_PACKAGE_ROOT=${INTELFPGAOCLSDKROOT}/board/intel_a10gx_pac
export LD_LIBRARY_PATH=${AOCL_BOARD_PACKAGE_ROOT}/linux64/lib:${INTELFPGAOCLSDKROOT}/host/linux64/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export PATH=${INTELFPGAOCLSDKROOT}/bin${PATH:+:${PATH}}
EOF

	. /opt/intelrtestack/init_env.sh

	mkdir ${INTELFPGAOCLSDKROOT}/board
	mv intel_a10gx_pac ${AOCL_BOARD_PACKAGE_ROOT}

	sed -e 's|PAC_CARD=""|PAC_CARD="pac_a10"|g' -e '/^check_for_card$/d' -e '/^init_pac_bsp$/d' -i.bak ${AOCL_BOARD_PACKAGE_ROOT}/linux64/libexec/install
	yes | PAC_BSP_ENV_NO_PERMISSIONS_INSTALL=1 aocl install
	mv ${AOCL_BOARD_PACKAGE_ROOT}/linux64/libexec/install.bak ${AOCL_BOARD_PACKAGE_ROOT}/linux64/libexec/install

	echo -n pac_a10 > /etc/fpga-variant
	cat << 'EOF' > /opt/intelrtestack/init_devices.sh
#!/bin/bash
source /opt/intelrtestack/init_env.sh
BSP_ROOT=${AOCL_BOARD_PACKAGE_ROOT}
PAC_CARD=$(cat /etc/fpga-variant)
EOF
	sed -e '/^check_res() {$/,/^}$/p' -e '/^configure_permission() {$/,/^}$/p' -e '/^error() {$/,/^}$/p' -e '/^init_pac_bsp() {$/,/^}$/p' -n ${AOCL_BOARD_PACKAGE_ROOT}/linux64/libexec/install >> /opt/intelrtestack/init_devices.sh
	cat << 'EOF' >> /opt/intelrtestack/init_devices.sh
configure_permission
init_pac_bsp
EOF
	chmod +x /opt/intelrtestack/init_devices.sh
	echo '@reboot PAC_BSP_ENV_NUM_HUGEPAGES=32 /opt/intelrtestack/init_devices.sh' | crontab

	# Install InAccel runtime
	apt install -o Dpkg::Options::=--refuse-downgrade -y --allow-downgrades ./inaccel-fpga.deb
	sed -e "s|/path/to/host|${INTELFPGAOCLSDKROOT}/host|" -e "s|/path/to/opencl_bsp|${AOCL_BOARD_PACKAGE_ROOT}|" -i /etc/inaccel/runtimes/intel-fpga/inaccel.pc
fi
