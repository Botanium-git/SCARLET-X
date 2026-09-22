ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = ScarletX
ScarletX_FILES = main.m AppDelegate.m BrowserViewController.m ScarletXScripts.m ScarletXDiagnosticsScripts.m DiagnosticsStore.m SettingsViewController.m LogViewController.m
ScarletX_FRAMEWORKS = UIKit WebKit
ScarletX_CFLAGS = -fobjc-arc
ScarletX_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	$(ECHO_NOTHING)$(FAKEROOT) chmod 755 $(THEOS_STAGING_DIR)/Applications/ScarletX.app/ScarletX$(ECHO_END)
