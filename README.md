# Chip utils


## Linux-specific
Linux requires permissions to write to C.H.I.P. when its plugged into your computer. Chrome (or Chromium) does not have these permissions, so you need to explicitly create them before you’ll be able to use the web flasher .

### On Ubuntu:


```
sudo usermod -a -G dialout $(logname)
sudo usermod -a -G plugdev $(logname)

# Create udev rules 
echo -e 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="efe8", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip"
SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="1010", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip-fastboot"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="1010", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip-fastboot"
SUBSYSTEM=="usb", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", GROUP="plugdev", MODE="0660" SYMLINK+="usb-serial-adapter"
' | sudo tee /etc/udev/rules.d/99-allwinner.rules

sudo udevadm control --reload-rules
```

Then logout and log back in.

For the curious:

logname: outputs your username
dialout: gives non-root access to serial connections
plugdev: allows non-root mounting with pmount
The udev rules then map the usb device to the groups.