#
#  From this base-image / starting-point
#
FROM debian:sid

#
#  Authorship
#
MAINTAINER ss34@sanger.ac.uk

#
# use not too ancient versions
#
RUN echo "deb http://ftp.de.debian.org/debian/ sid main non-free contrib" >> /etc/apt/sources.list.d/sid.list; \
    apt-get update

#
# install dependencies
#
RUN apt-get install genometools bowtie2 tophat cufflinks --yes --force-yes