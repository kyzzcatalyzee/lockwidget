TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = lockwidgetsizeprefs

lockwidgetsizeprefs_FILES = LWSRootListController.m
lockwidgetsizeprefs_FRAMEWORKS = UIKit
lockwidgetsizeprefs_PRIVATE_FRAMEWORKS = Preferences
lockwidgetsizeprefs_INSTALL_PATH = /Library/PreferenceBundles
lockwidgetsizeprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
