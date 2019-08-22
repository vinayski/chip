################################################################################
#
# rtl8723ds MP SDIO WiFi Driver
#
################################################################################

RTL8723DS_MP_DRIVER_VERSION = $(call qstrip,$(BR2_PACKAGE_RTL8723DS_MP_DRIVER_VERSION))
RTL8723DS_MP_DRIVER_SOURCE = rtl8723DS_WiFi_linux_$(RTL8723DS_MP_DRIVER_VERSION).tar.gz
RTL8723DS_MP_DRIVER_SITE = https://github.com/NextThingCo/RTL8723DS
RTL8723DS_MP_DRIVER_SITE_METHOD = git

RTL8723DS_MP_DRIVER_DEPENDENCIES = linux
#RTL8723DS_MP_DRIVER_INSTALL_STAGING = YES
RTL8723DS_MP_DRIVER_LICENSE = GPLv2

ifeq ($(BR2_PACKAGE_RTL8723DS_MP_DRIVER_CUSTOM_GIT),y)
RTL8723DS_MP_DRIVER_SITE = $(call qstrip,$(BR2_PACKAGE_RTL8723DS_MP_DRIVER_CUSTOM_REPO_URL))
RTL8723DS_MP_DRIVER_SITE_METHOD = git
BR_NO_CHECK_HASH_FOR += $(RTL8723DS_MP_DRIVER_SOURCE)
endif

RTL8723DS_MAKE_FLAGS += -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT
RTL8723DS_MAKE_FLAGS += -DCONFIG_CONCURRENT_MODE=y
RTL8723DS_MAKE_FLAGS += -DCONFIG_AUTO_AP_MODE=y
RTL8723DS_MAKE_FLAGS += -DCONFIG_MP_INCLUDED=y
RTL8723DS_MAKE_FLAGS += -DCONFIG_WIFI_MONITOR=y

RTL8723DS_MP_DRIVER_MODULE_MAKE_OPTS = CONFIG_RTL8723DS=m USER_EXTRA_CFLAGS="$(RTL8723DS_MAKE_FLAGS)" KSRC=$(LINUX_DIR)

RTL8723DS_MP_DRIVER_POST_INSTALL_TARGET_HOOKS += RTL8723DS_MP_DRIVER_EXTRA_INSTALL

define RTL8723DS_MP_DRIVER_EXTRA_INSTALL
	$(HOST_DIR)/sbin/depmod -a -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
	$(INSTALL) -D -m 0644 package/rtl8723ds_mp_driver/rtl8723ds_mp.conf \
		$(TARGET_DIR)/etc/modprobe.d/rtl8723ds_mp.conf
	$(INSTALL) -m 0755 -D package/rtl8723ds_mp_driver/S20_rtl8723ds_mp_wifi $(TARGET_DIR)/etc/init.d/S20_rtl8723ds_mp_wifi

  $(INSTALL) -D -m 0755 package/rtl8723ds_mp_driver/set_antenna $(TARGET_DIR)/usr/bin/set_antenna
  $(INSTALL) -D -m 0755 package/rtl8723ds_mp_driver/w_start $(TARGET_DIR)/usr/bin/w_start
  $(INSTALL) -D -m 0755 package/rtl8723ds_mp_driver/w_stop  $(TARGET_DIR)/usr/bin/w_stop
  $(INSTALL) -D -m 0755 package/rtl8723ds_mp_driver/w       $(TARGET_DIR)/usr/bin/w
endef

$(eval $(kernel-module))
$(eval $(generic-package))
