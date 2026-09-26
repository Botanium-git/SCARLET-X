ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = ScarletX
ScarletX_FILES = App/main.m App/AppDelegate.m Browser/BrowserViewController.m Browser/BrowserViewController+Navigation.m Browser/AccountSwitchProbe.m Browser/ClosedDOMStructureProbe.m Scripts/DisplayScripts.m Scripts/DiagnosticsScripts.m Scripts/RuntimeScripts.m Scripts/MenuScripts.m Diagnostics/DiagnosticsStore.m UI/SettingsViewController.m UI/LogViewController.m UI/NativeDrawerViewController.m UI/QuickLogExport.m
ScarletX_FRAMEWORKS = UIKit WebKit
ScarletX_CFLAGS = -fobjc-arc
ScarletX_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	$(ECHO_NOTHING)$(FAKEROOT) chmod 755 $(THEOS_STAGING_DIR)/Applications/ScarletX.app/ScarletX$(ECHO_END)
