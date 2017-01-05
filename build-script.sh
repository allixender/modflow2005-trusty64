#!/bin/bash

export RUNTIME_PACKAGES="wget libxml2 curl openssl libgd-dev libfcgi0ldbl libcairo2 	\
libgdal1h libgeos-3.4.2 libgeos-c1 libgfortran3 gfortran-multilib libmozjs185-1.0 libproj0  \
libjpeg62 libpng3 libxslt1.1 python2.7 apache2 python-tk"

apt-get update -y \
      && apt-get install -y --no-install-recommends $RUNTIME_PACKAGES

export BUILD_PACKAGES="subversion unzip flex bison libxml2-dev autoconf libmozjs185-dev python-dev \
build-essential libxslt1-dev software-properties-common libgdal-dev automake libtool libcairo2-dev \
libgd2-xpm-dev libgd-gd2-perl \
libproj-dev libnetcdf-dev libfreetype6-dev gfortran python-pip  libxslt1-dev libfcgi-dev"

# the whole Python building and build essentials might be worth to extract out to keep image small again
apt-get install -y --no-install-recommends $BUILD_PACKAGES

# for gdal python
export CPLUS_INCLUDE_PATH=/usr/include/gdal
export C_INCLUDE_PATH=/usr/include/gdal

pip install python-dateutil numpy
pip install matplotlib netcdf4
pip install flopy gdal==1.10.0
pip install OWSlib Pyshp

# for mapserver
export CMAKE_C_FLAGS=-fPIC
export CMAKE_CXX_FLAGS=-fPIC

# useful declarations
export BUILD_ROOT=/opt/build
export ZOO_BUILD_DIR=/opt/build/zoo-project
export CGI_DIR=/usr/lib/cgi-bin
export CGI_DATA_DIR=/usr/lib/cgi-bin/data

# seems to help mapserver find xslt
mkdir -p $BUILD_ROOT \
  && mkdir -p $CGI_DIR \
  && ln -s /usr/lib/x86_64-linux-gnu /usr/lib64

# get and Compile MapServer
# patch Makefile for lib-geos-4.2.3_c
# GEOS_LIB=  -L/usr/lib -lgeos-3.4.2 -lgeos_c
# http://zoo-project.org/docs/kernel/mapserver.html#kernel-mapserver  / 7.0.1?
# http://download.osgeo.org/mapserver/mapserver-7.0.1.tar.gz
wget -nv -O $BUILD_ROOT/mapserver-6.0.4.tar.gz http://download.osgeo.org/mapserver/mapserver-6.0.4.tar.gz \
  && cd $BUILD_ROOT/ && tar -xzf mapserver-6.0.4.tar.gz \
  && cd $BUILD_ROOT/mapserver-6.0.4 \
  && ./configure --with-ogr=/usr/bin/gdal-config --with-gdal=/usr/bin/gdal-config \
               --with-proj --with-curl --with-sos --with-wfsclient --with-wmsclient \
               --with-wcs --with-wfs --with-kml=yes --with-geos \
               --with-xml --with-xslt --with-threads --with-cairo \
  && sed -i "s/-lgeos-3.4.2_c/-lgeos-3.4.2\ -lgeos_c/g" Makefile \
  && sed -i "s/-lm -lstdc++/-lm -lstdc++ -ldl/g" Makefile \
  && make && cp mapserv $CGI_DIR

# or else thirds cgic206 can't find fastcgi
ln -s /usr/lib/libfcgi.so.0.0.0 /usr/lib64/libfcgi.so \
  && ln -s /usr/lib/libfcgi++.so.0.0.0 /usr/lib64/libfcgi++.so

# here are the thirds
svn checkout http://svn.zoo-project.org/svn/trunk/thirds/ $BUILD_ROOT/thirds \
  && cd $BUILD_ROOT/thirds/cgic206 && make

# zoo configure option
# --with-cgi-dir=/usr/lib/cgi-bin is default
# --with-fastcgi=/usr
# --with-gdal-config=/usr/bin/gdal-config
# --with-geosconfig=/usr/bin/geos-config
# --with-cgal=/usr
# --with-mapserver=/path/to/your/mapserver_config/
# --with-python --with-mapserver=/tmp/zoo-ms-src/mapserver-6.0.1
# --with-xml2config=/usr/bin/xml2-config
# --with-python=/usr/local
# --with-pyvers=2.7
# --with-js=/usr/local
# --with-java=/usr/lib/jvm/java-7-openjdk/
# --with-otb=/path/to/your/otb/
# --with-itk-version
# --with-saga=/path/to/your/saga/
# --with-wx-config
svn checkout http://svn.zoo-project.org/svn/trunk/zoo-project/ $ZOO_BUILD_DIR \
  && cd $ZOO_BUILD_DIR/zoo-kernel && autoconf \
  && ./configure --with-cgi-dir=$CGI_DIR \
  --prefix=/usr \
  --exec-prefix=/usr \
  --with-fastcgi=/usr \
  --with-gdal-config=/usr/bin/gdal-config \
  --with-geosconfig=/usr/bin/geos-config \
  --with-python \
  --with-mapserver=$BUILD_ROOT/mapserver-6.0.4 \
  --with-xml2config=/usr/bin/xml2-config \
  --with-pyvers=2.7 \
  --with-js=/usr \
  && make && make install

# however, auto additonal packages won't get removed
# maybe auto remove is a bit too hard
# RUN apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
# ENV AUTO_ADDED_PACKAGES $(apt-mark showauto)
# RUN apt-get remove --purge -y $BUILD_PACKAGES $AUTO_ADDED_PACKAGES

apt-get remove --purge -y $BUILD_PACKAGES \
  && rm -rf /var/lib/apt/lists/*

rm -rf $BUILD_ROOT/mapserver-6.0.4
rm $BUILD_ROOT/mapserver-6.0.4.tar.gz
rm -rf $ZOO_BUILD_DIR
# rm -rf $BUILD_ROOT/thirds
