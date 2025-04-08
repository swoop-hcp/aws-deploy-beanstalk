FROM amazonlinux:2

RUN yum install -y unzip curl python3 jq && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    yum clean all && \
    rm -rf awscliv2.zip aws/

RUN which jq && jq --version

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]