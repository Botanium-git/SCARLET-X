ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = ScarletX
ScarletX_FILES = App/main.m App/AppDelegate.m Browser/BrowserViewController.m Browser/BrowserViewController+Navigation.m Scripts/ScarletXScripts.m Scripts/ScarletXDiagnosticsScripts.m Scripts/ScarletXPerformanceScripts.m Scripts/ScarletXMenuScripts.m Diagnostics/DiagnosticsStore.m UI/SettingsViewController.m UI/LogViewController.m
ScarletX_FRAMEWORKS = UIKit WebKit
ScarletX_CFLAGS = -fobjc-arc
ScarletX_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	$(ECHO_NOTHING)$(FAKEROOT) chmod 755 $(THEOS_STAGING_DIR)/Applications/ScarletX.app/ScarletX$(ECHO_END)
