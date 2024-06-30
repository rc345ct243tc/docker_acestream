FROM --platform=$BUILDPLATFORM ubuntu:22.04 as build

RUN apt-get update && \
    apt-get install -y unzip git wget && \
    rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
ENV ACESTREAM_VERSION=3.1.80.0

RUN if [ $TARGETARCH = "amd64" ]; then \
      wget -q https://download.acestream.media/android/core.web/stable/AceStreamCore-$ACESTREAM_VERSION-x86_64.apk -O /tmp/AceStreamCore.apk; \
    elif [ $TARGETARCH = "arm64" ]; then \
      wget -q https://download.acestream.media/android/core.web/stable/AceStreamCore-$ACESTREAM_VERSION-armv8_64.apk -O /tmp/AceStreamCore.apk; \
    fi   

RUN cd /tmp/ && \
    unzip -q AceStreamCore.apk -d acestream_bundle && \
    if [ $TARGETARCH = "amd64" ]; then \
      unzip -q acestream_bundle/assets/engine/x86_64_private_py.zip -d acestream_engine && \
      unzip -q acestream_bundle/assets/engine/x86_64_private_res.zip -d acestream_engine; \
    elif [ $TARGETARCH = "arm64" ]; then \
      unzip -q acestream_bundle/assets/engine/arm64-v8a_private_py.zip -d acestream_engine && \
      unzip -q acestream_bundle/assets/engine/arm64-v8a_private_res.zip -d acestream_engine; \
    fi && \
    unzip -q acestream_bundle/assets/engine/public_res.zip -d acestream_engine && \
    unzip -q acestream_engine/python/lib/stdlib.zip -d acestream_engine/python/lib/python3.8/ && \
    mv acestream_engine/python/lib/modules/* acestream_engine/python/lib/python3.8/site-packages/ && \
    rm -rf acestream_bundle && \
    rm /tmp/AceStreamCore.apk

# Patch request.py in urllib to make DNS work
COPY request.patch /tmp/
RUN cd /tmp/acestream_engine/python/lib/python3.8/urllib && \
    wget -q https://raw.githubusercontent.com/python/cpython/3.8/Lib/urllib/request.py && \
    git apply /tmp/request.patch && \
    rm request.pyc && \
    rm /tmp/request.patch

# Patch socket.py to make DNS work. No needed
# COPY socket.patch /tmp/
# RUN cd /tmp/acestream_engine/python/lib/python3.8/ && \
#     wget -q https://raw.githubusercontent.com/python/cpython/3.8/Lib/socket.py && \
#     git apply /tmp/socket.patch && \
#     rm socket.pyc && \
#     rm /tmp/socket.patch

# Install DNSPython Library for above DNS hacks
RUN cd /tmp/acestream_engine/python/lib/python3.8/ && \
    git clone https://github.com/rthalley/dnspython/ && \
    mv dnspython/dns dns && \
    rm -rf dnspython && \
    rm /tmp/acestream_engine/eggs/dnspython-2.0.0-py3.8.egg

# Patch app_bridge.py to make device metrics collection work. No needed
# COPY app_bridge.patch /tmp/
# RUN cd /tmp/acestream_engine/ && \
#      git apply /tmp/app_bridge.patch && \
#      rm /tmp/app_bridge.patch

FROM scratch

ARG TARGETARCH

COPY --from=build /tmp/acestream_engine/ /data/data/org.acestream.media/files/
COPY $TARGETARCH/system/ /system/
COPY hosts /system/etc/hosts

COPY main.py /data/data/org.acestream.media/files/

ENV PYTHONHOME=/data/data/org.acestream.media/files/python
ENV PYTHONPATH=$PYTHONHOME/lib
ENV PATH=$PYTHONHOME/bin:$PATH
ENV LD_LIBRARY_PATH=/data/data/org.acestream.media/files/python/lib:/system/lib

WORKDIR /data/data/org.acestream.media/files/
ENTRYPOINT ["python", "main.py", "--client-console", "--disable-sentry"]

