#
#  Dockerfile for a GPDB Base Image w/ CRoaring bitmap extension
#

FROM centos:6.9
MAINTAINER jack.wang@vungle.com

COPY * /tmp/
RUN echo root:pivotal | chpasswd \
        && yum install -y centos-release-scl-rh \
        && yum install -y devtoolset-3-gcc devtoolset-3-gcc-c++ \
        && yum install -y unzip which tar more util-linux-ng passwd openssh-clients openssh-server ed m4; yum clean all \
        && unzip /tmp/greenplum-db-5.0.0-beta.4-rhel6-x86_64.zip -d /tmp/ \
        && rm /tmp/greenplum-db-5.0.0-beta.4-rhel6-x86_64.zip \
        && sed -i s/"more << EOF"/"cat << EOF"/g /tmp/greenplum-db-5.0.0-beta.4-rhel6-x86_64.bin \
        && echo -e "yes\n\nyes\nyes\n" | /tmp/greenplum-db-5.0.0-beta.4-rhel6-x86_64.bin \
        && rm /tmp/greenplum-db-5.0.0-beta.4-rhel6-x86_64.bin \
        && cat /tmp/sysctl.conf.add >> /etc/sysctl.conf \
        && cat /tmp/limits.conf.add >> /etc/security/limits.conf \
        && rm -f /tmp/*.add \
        && echo "localhost" > /tmp/gpdb-hosts \
        && chmod 777 /tmp/gpinitsystem_singlenode \
        && hostname > ~/orig_hostname \
        && mv /tmp/run.sh /usr/local/bin/run.sh \
        && chmod +x /usr/local/bin/run.sh \
        && /usr/sbin/groupadd gpadmin \
        && /usr/sbin/useradd gpadmin -g gpadmin -G wheel \
        && echo "pivotal"|passwd --stdin gpadmin \
        && echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers \
        && mv /tmp/bash_profile /home/gpadmin/.bash_profile \
        && chown -R gpadmin: /home/gpadmin \
        && mkdir -p /gpdata/master /gpdata/segments \
        && chown -R gpadmin: /gpdata \
        && chown -R gpadmin: /usr/local/green* \
        && service sshd start \
        && su gpadmin -l -c "source /usr/local/greenplum-db/greenplum_path.sh;gpssh-exkeys -f /tmp/gpdb-hosts"  \
        && su gpadmin -l -c "source /usr/local/greenplum-db/greenplum_path.sh;gpinitsystem -a -c  /tmp/gpinitsystem_singlenode -h /tmp/gpdb-hosts; exit 0 "\
        && su gpadmin -l -c "export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1;source /usr/local/greenplum-db/greenplum_path.sh;psql -d template1 -c \"alter user gpadmin password 'pivotal'\"; createdb gpadmin;  exit 0"

RUN export PATH=/opt/rh/devtoolset-3/root/usr/bin:$PATH \
        && unzip /tmp/gpdb-roaringbitmap.zip -d /tmp/ \
        && cd /tmp/gpdb-roaringbitmap/ \
        && gcc -march=native -O3 -std=c11 -Wall -Wpointer-arith \
               -Wendif-labels -Wformat-security -fno-strict-aliasing \
               -fwrapv -fexcess-precision=standard -fno-aggressive-loop-optimizations \
               -Wno-unused-but-set-variable -Wno-address -Werror=implicit-function-declaration -fpic -D_GNU_SOURCE \
               -I/usr/local/greenplum-db/include/postgresql/server \
               -I/usr/local/greenplum-db/include/postgresql/internal \
               -c -o roaringbitmap.o roaringbitmap.c \
        && gcc -march=native -O3 -std=c11 -Wall -Wpointer-arith  -Wendif-labels -Wformat-security \
               -fno-strict-aliasing -fwrapv -fexcess-precision=standard -fno-aggressive-loop-optimizations \
               -Wno-unused-but-set-variable -Wno-address  -fpic -shared --enable-new-dtags \
               -o roaringbitmap.so roaringbitmap.o \
        && cp ./*.sql /home/gpadmin \
        && cp ./roaringbitmap.so /usr/local/greenplum-db/lib/postgresql/ \
        && chown gpadmin:gpadmin /home/gpadmin/*.sql \
        && chown gpadmin:gpadmin /usr/local/greenplum-db/lib/postgresql/roaringbitmap.so

EXPOSE 5432 22

VOLUME /gpdata

# Set the default command to run when starting the container
CMD echo "127.0.0.1 $(cat ~/orig_hostname)" >> /etc/hosts \
        && service sshd start \
#       && sysctl -p \
        && su gpadmin -l -c "/usr/local/bin/run.sh" \
        && su gpadmin -l -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/greenplum-db/lib:/usr/local/greenplum-db/lib/postgresql;psql -f ~/roaringbitmap.sql;" \
        && /bin/bash
