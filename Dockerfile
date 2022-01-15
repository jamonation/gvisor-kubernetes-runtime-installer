FROM alpine:latest

COPY install-gvisor.sh /install-gvisor.sh

CMD /install-gvisor.sh
