ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = ScarletX
ScarletX_FILES = App/main.m App/AppDelegate.m Browser/BrowserViewController.m Browser/BrowserViewController+Navigation.m Browser/BrowserViewController+InteractionPolicy.m Browser/BrowserViewController+PortraitMediaFix.m Browser/AccountSwitchProbe.m Browser/NativeProfileBridge.m Browser/NativeProfileInternalPosts211.m Browser/NativeProfileMediaFix212.m Browser/NativeProfileRepliesFix231.m Browser/NativeProfileReposts236.m Browser/NativeProfilePagination238.m Browser/NativeProfilePaginationEntry238.m Browser/NativeProfilePaginationRecovery248.m Browser/NativeNavigation217.m Browser/NativeNavigation218.m Browser/NativeProfileIdentityFix219.m Browser/InternalProfileAPIBridge.m Browser/InternalProfileAPIFiberRecoveryFix.m Browser/InternalProfileAPIProfileEntryRecovery240.m Browser/NativeEndpointFactory245.m Browser/NativeProfileInitialCount255.m Browser/NativeProfileLoaderDiagnostics.m Browser/NativeProfileRequestProbe.m Browser/MainWebGraphQLProbe.m Browser/MainWebModule830959Probe.m Browser/MainWebModule658009Probe.m Scripts/DisplayScripts.m Scripts/DiagnosticsScripts.m Scripts/RuntimeScripts.m Scripts/MenuScripts.m Diagnostics/DiagnosticsStore.m Diagnostics/ClosedDOMStructureProbe.m Diagnostics/QuickLogExport.m UI/SettingsViewController.m UI/LogViewController.m UI/NativeDrawerViewController.m UI/NativeProfileViewController.m UI/NativeProfileMediaGrid212.m UI/NativeProfileTransition217.m UI/NativeTransitionSpeed218.m UI/NativeGestures221.m UI/NativeProfileIncrementalUpdate223.m UI/NativeProfileAppend247.m UI/NativeProfileStackWindow276.m UI/NativeGestures224.m UI/NativePolish225.m UI/NativeProfilePolish230.m UI/NativeProfileTabAnimation234.m UI/NativeImageCache235.m UI/NativeCountFormat238.m
ScarletX_FRAMEWORKS = UIKit WebKit AVKit AVFoundation
ScarletX_CFLAGS = -fobjc-arc
ScarletX_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	$(ECHO_NOTHING)$(FAKEROOT) chmod 755 $(THEOS_STAGING_DIR)/Applications/ScarletX.app/ScarletX$(ECHO_END)
