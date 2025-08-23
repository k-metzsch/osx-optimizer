#!/bin/bash
mount_9p hostshare

sudo usbfluxd -f -r 172.17.0.1:5000
