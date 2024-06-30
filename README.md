# Acestream Docker Image
This repo aims to create a minimal image running the acestream engine server for multiple platforms (amd64, arm64). The image makes use of the AceStreamCore android APKs and sets everything up in a container containing a minimal android based command line environment to run the tool in. 

While AceStreamCore is distributed as a python app within the android APK, it will not run inside a normal linux distro as it is compiled against python-for-android. The apk also distributes the python bits needed for running the engine, so we only need to source an Android CLI environment to run this all in. To keep this reproducible, we make use of the Android 12 GSI images from [here](https://ci.android.com/builds/branches/aosp-android12-gsi/grid?legacy=1).

The part of obtaining the tools from the GSI image has to be done manually for 2 reasons: First, Google doesn't seem to have a simple wget downloadable link for the image, and Second, we need to mount the image using a loop device to extract files from it and this cannot be done easily as part of a docker build process without privileged permissions. So you'll need to download this zip file on your own, run the `process_aosp.sh` script (as mentioned in Build Instructions) before the docker image can be built.

Most of the build process is inspired from [this repo](https://github.com/miltador/cheapstream).

## Images
Images are built with docker multiarch manifest support, so a single URL should pull the correct image for your architecture

| AceStreamCore Version | Architecture | AOSP GSI Used                         | Image                                          |
|-----------------------|--------------|---------------------------------------|------------------------------------------------|
| `3.1.80.0`              | `amd64`        | `aosp_x86_64-target_files-12016473.zip` | `ghcr.io/rc345ct243tc/docker_acestream:3.1.80.0` |
| `3.1.80.0`              | `arm64`        | `aosp_arm64-target_files-12016473.zip`  | `ghcr.io/rc345ct243tc/docker_acestream:3.1.80.0` |

## Gluetun Support
These images have been tested and work with [gluetun](https://github.com/qdm12/gluetun). Set the `network`/`network_mode` argument approriately and it should run over a VPN.

## Build Instructions
An Android GSI Image is needed to pull a couple of system level binaries. This needs to be manually downloaded from [here](https://ci.android.com/builds/branches/aosp-android12-gsi/grid?legacy=1). Select the correct file for your architecture (`aosp_x86_64`/`aosp_arm64`), click on the newest build and download the `aosp_XXX-target_files-YYYYY.zip` file. The arch names used by android is different from what we'll be using for rest of the build process.
Place this in a folder named `$ARCH` (we'll be calling it `amd64`/`arm64` from now on) depending on the architecture and run this command to extract the system files `bash process_aosp.sh $ZIPFILE $ARCH`. This will create a folder names `system` inside the `$ARCH` folder. This script needs to mount `.img` files and needs access to a loop device, which means it's unlikely it will run inside a container and needs sudo access on the host it's being built on. The docker image can now be built with `docker build --arch $ARCH -t tag .`

Example commands
```bash
mkdir amd64
cp location/of/download/aosp_x86_64-target_files-12016473.zip amd64/
bash process_aosp.sh aosp_x86_64-target_files-12016473.zip amd64
docker build --arch amd64 -t docker_acestream .
```

## Hacks Used in Build Process
Since we're using things in ways in which it wasn't meant to be used, there are a couple of hacks added to the build process to make things work fine. These hacks might break and need to be edited for future versions. The hacks have been supplied as patches so that they are easily adaptable for the future. Credit to the patches go to [miltador](https://github.com/miltador/cheapstream/tree/master/mods/python27)

1. [A patch](./request.patch) to `request.py` - DNS resolution doesn't work within the `python-for-android` environment used by Acestream. For this, a patch is made to the `urllib` library in python
2. A custom [hosts file](./hosts) has to be added with entries for hostnames used by DHT
3. **NOT NEEDED** - [A patch](./app_bridge.patch) to `app_bridge.py` to report all device metrics properly. If this patch isn't applied, you'll see a lot of errors in the container logs, but this doesn't affect funtionality
4. **NOT NEEDED** - [A patch](./socket.patch) to `socket.py` in the python library to fix DNS. It looks like this isn't needed as things work fine without this
