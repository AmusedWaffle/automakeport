#!/bin/sh 
#
# Pre-requisites: 
#  - cd to the directory of this script before running the script   
#  - ensure you have sourced setenv.sh, e.g. . ./setenv.sh
#  - ensure you have GNU make installed (4.1 or later)
#  - ensure you have Perl installed (Perl 5.006 or later)
#  - ensure you have access to c99
#  - ensure you have built and installed autoconf and m4 already
#  - either pre-install the AUTOMAKE tar ball into AUTOMAKE_ROOT or have curl/gunzip installed for auto-download
#
#set -x
if [ "${AUTOMAKE_ROOT}" = '' ]; then
	echo "Need to set AUTOMAKE_ROOT - source setenv.sh" >&2
	exit 16
fi
if [ "${AUTOMAKE_VRM}" = '' ]; then
	echo "Need to set AUTOMAKE_VRM - source setenv.sh" >&2
	exit 16
fi

make --version >/dev/null 2>&1 
if [ $? -gt 0 ]; then
	echo "You need GNU Make on your PATH in order to build AUTOMAKE" >&2
	exit 16
fi

perl --version >/dev/null 2>&1 
if [ $? -gt 0 ]; then
	echo "You need perl on your PATH in order to build AUTOMAKE" >&2
	exit 16
fi

m4 --version >/dev/null 2>&1 
if [ $? -gt 0 ]; then
	echo "You need m4 on your PATH in order to build AUTOMAKE" >&2
	exit 16
fi

autoconf --version >/dev/null 2>&1 
if [ $? -gt 0 ]; then
	echo "You need autoconf on your PATH in order to build AUTOMAKE" >&2
	exit 16
fi

whence c99 >/dev/null
if [ $? -gt 0 ]; then
	echo "c99 required to build AUTOMAKE. " >&2
	exit 16
fi

MY_ROOT="${PWD}"

if [ "${AUTOMAKE_VRM}" != "automake" ]; then
	# Non-dev - get the tar file
	rm -rf "${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}"
	if ! mkdir -p "${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}" ; then
		echo "Unable to make root AUTOMAKE directory: ${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}" >&2
		exit 16
	fi
	cd "${AUTOMAKE_ROOT}" || exit 99

	if ! [ -f "${AUTOMAKE_VRM}.tar" ]; then
		echo "automake tar file not found. Attempt to download with curl" 
		if ! whence curl >/dev/null ; then
			echo "curl not installed. You will need to upload AUTOMAKE, or install curl/gunzip from ${AUTOMAKE_URL}" >&2
			exit 16
		fi	
		if ! whence gunzip >/dev/null ; then
			echo "gunzip required to unzip AUTOMAKE. You will need to upload AUTOMAKE, or install curl/gunzip from ${AUTOMAKE_URL}" >&2
			exit 16
		fi	
		if ! (rm -f ${AUTOMAKE_VRM}.tar.gz; curl -s --output ${AUTOMAKE_VRM}.tar.gz http://ftp.gnu.org/gnu/automake/${AUTOMAKE_VRM}.tar.gz) ; then
			echo "curl failed with rc $rc when trying to download ${AUTOMAKE_VRM}.tar.gz" >&2
			exit 16
		fi	
		chtag -b ${AUTOMAKE_VRM}.tar.gz
		if ! gunzip ${AUTOMAKE_VRM}.tar.gz ; then
			echo "gunzip failed with rc $rc when trying to unzip ${AUTOMAKE_VRM}.tar.gz" >&2
			exit 16
		fi	
	fi

	tar -xf "${AUTOMAKE_VRM}.tar" 2>/dev/null
# TBD: figure out how to get GUID/UID to not be set on untar
	if [ $? -gt 1 ]; then
		echo "Unable to make untar AUTOMAKE drop: ${AUTOMAKE_VRM}" >&2
		exit 16
	fi
else
	cd "${AUTOMAKE_ROOT}"
fi
if ! chtag -R -h -t -cISO8859-1 "${AUTOMAKE_VRM}" ; then 
	echo "Unable to tag AUTOMAKE directory tree as ASCII" >&2
	exit 16
fi

DELTA_ROOT="${PWD}"

cd "${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}" || exit 99

if [ "${AUTOMAKE_VRM}" = "automake" ]; then
	./bootstrap
	if [ $? -gt 0 ]; then
		echo "Bootstrap of AUTOMAKE dev-line failed." >&2
		exit 16
	fi
fi

#
# Setup the configuration so that the system search path looks in lib and include ahead of the standard C libraries
#
export CC=xlclang
export CFLAGS="-qascii -D_OPEN_THREADS=3 -D_UNIX03_SOURCE=1 -DNSIG=39 -qnose -I${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}/lib,${DELTA_ROOT}/include,/usr/include"
if ! ./configure --prefix="${AUTOMAKE_PROD}" ; then
	echo "Configure of AUTOMAKE tree failed." >&2
	exit 16
fi

cd "${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}" || exit 99
if ! make ; then
	echo "MAKE of AUTOMAKE tree failed." >&2
	exit 16
fi

cd "${DELTA_ROOT}/tests"
export PATH="${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}/src:${PATH}"

if ! ./runbasic.sh ; then
	echo "Basic test of AUTOMAKE failed." >&2
	exit 16
fi

if ! ./runexamples.sh ; then
	echo "Example tests of AUTOMAKE failed." >&2
	exit 16
fi

cd "${AUTOMAKE_ROOT}/${AUTOMAKE_VRM}" || exit 99
# make check has to be run in 'sh' and not bash
if ! sh -c 'make check' ; then
	echo "MAKE check of AUTOMAKE tree failed." >&2
	exit 16
fi
if ! make install ; then
	echo "MAKE install of AUTOMAKE tree failed." >&2
	exit 16
fi
exit 0