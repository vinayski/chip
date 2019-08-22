################################################################################
#
# sunxi-tools
#
################################################################################

SUNXI_TOOLS_VERSION = v1.4.2
SUNXI_TOOLS_REPO_NAME = sunxi-tools
SUNXI_TOOLS_SITE = https://github.com/linux-sunxi/$(SUNXI_TOOLS_REPO_NAME)
SUNXI_TOOLS_SITE_METHOD=git
SUNXI_TOOLS_LICENSE = GPLv2+
SUNXI_TOOLS_LICENSE_FILES = COPYING
HOST_SUNXI_TOOLS_DEPENDENCIES = host-libusb host-pkgconf
FEX2BIN = $(HOST_DIR)/usr/bin/fex2bin

define HOST_SUNXI_TOOLS_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE) CC="$(HOSTCC)" PREFIX=$(HOST_DIR)/usr \
		EXTRA_CFLAGS="$(HOST_CFLAGS)" LDFLAGS="$(HOST_LDFLAGS)" \
		-C $(@D)
	$(HOST_MAKE_ENV) $(MAKE) CC="$(HOSTCC)" PREFIX=$(HOST_DIR)/usr \
		EXTRA_CFLAGS="$(HOST_CFLAGS)" LDFLAGS="$(HOST_LDFLAGS)" \
		-C $(@D) misc
endef

define HOST_SUNXI_TOOLS_INSTALL_CMDS
	$(HOST_MAKE_ENV) $(MAKE) PREFIX=$(HOST_DIR)/usr \
		-C $(@D) install
	$(INSTALL) -D -m 0755 $(@D)/sunxi-* $(HOST_DIR)/usr/bin
endef

define SUNXI_TOOLS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) CC="$(TARGET_CC)" PREFIX=/usr \
		EXTRA_CFLAGS="$(TARGET_CFLAGS)" LDFLAGS="$(TARGET_LDFLAGS)" \
		-C $(@D) sunxi-nand-part
endef

define SUNXI_TOOLS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sunxi-nand-part $(TARGET_DIR)/usr/bin/sunxi-nand-part
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
