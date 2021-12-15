FROM rossbannerman/gh:latest
RUN apk --no-cache add git
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
