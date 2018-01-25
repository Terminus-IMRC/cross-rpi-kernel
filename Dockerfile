FROM idein/cross-rpi

USER root
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
     bc asciidoc xmlto \
 && apt-get clean && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

USER idein
CMD /bin/bash
