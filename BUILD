load(
    "@gnustep_make//bazel:objc.bzl",
    "gnustep_expand_template",
    "gnustep_platform_linkopts",
    "gnustep_target_copts",
    "objc_binary",
    "objc_library",
    "objc_test",
)

package(default_visibility = ["//visibility:public"])

gnustep_expand_template(
    name = "gen_gsversion_h",
    out = ".bazel/include/GNUstepGUI/GSVersion.h",
    substitutions = {
        "@GNUSTEP_GUI_VERSION@": "0.32.0",
        "@GNUSTEP_GUI_MAJOR_VERSION@": "0",
        "@GNUSTEP_GUI_MINOR_VERSION@": "32",
        "@GNUSTEP_GUI_SUBMINOR_VERSION@": "0",
    },
    template = "Headers/Additions/GNUstepGUI/GSVersion.h.in",
)

gnustep_expand_template(
    name = "gen_config_h",
    out = ".bazel/include/config.h",
    substitutions = {},
    template = ".bazel/config.h.in",
)

gnustep_expand_template(
    name = "gen_gnustepgui_config_h",
    out = ".bazel/include/GNUstepGUI/config.h",
    substitutions = {},
    template = ".bazel/config.h.in",
)

GUI_EXCLUDED_SRCS = [
    "Source/GSAudioPlayer.m",
    "Source/GSAVUtils.m",
    "Source/GSGhostscriptImageRep.m",
    "Source/GSMovieView.m",
    "Source/NSButtonImageSource.m",
]

objc_library(
    name = "gnustep-gui",
    srcs = glob(
        [
            "Source/*.m",
            "Source/*.h",
        ],
        allow_empty = True,
        exclude = GUI_EXCLUDED_SRCS,
    ) + [
        ":gen_config_h",
        ":gen_gnustepgui_config_h",
        ":gen_gsversion_h",
    ],
    hdrs = glob([
        "Headers/Additions/GNUstepGUI/*.h",
        "Headers/AppKit/*.h",
        "Headers/Cocoa/*.h",
        "Source/*.h",
    ]) + [
        ":gen_config_h",
        ":gen_gnustepgui_config_h",
        ":gen_gsversion_h",
    ],
    copts = [
        "-DGNUSTEP",
        "-DGNUSTEP_GUI_LIBRARY=1",
        "-DGNUSTEP_GUI_INTERNAL=1",
        "-DGNU_RUNTIME=1",
        "-D_NATIVE_OBJC_EXCEPTIONS=1",
        "-DGSWARN",
        "-DGSDIAGNOSE",
        "-DGNUSTEP_IS_FLATTENED=\"yes\"",
        "-DLIBRARY_COMBO=\"ng-gnu-gnu\"",
        "-DGNUSTEP_BASE_HAVE_LIBXML=1",
        "-DBACKEND_BUNDLE=1",
        "-Wno-protocol",
        "-Wno-deprecated-declarations",
        "-Wno-implicit-function-declaration",
        "-Wno-int-conversion",
        "-Wno-incompatible-pointer-types",
        "-Wno-unused-but-set-variable",
        "-Wno-unused-function",
        "-Wno-unused-variable",
        "-Wno-format",
        "-Wno-switch",
    ] + gnustep_target_copts(),
    defines = [
        "GNUSTEP",
        "GNU_RUNTIME=1",
        "_NATIVE_OBJC_EXCEPTIONS=1",
    ],
    includes = [
        ".bazel/include",
        ".bazel/include/GNUstepGUI",
        "Headers",
        "Headers/Additions",
        "Headers/Additions/GNUstepGUI",
        "Headers/AppKit",
        "Headers/Cocoa",
        "Source",
    ],
    linkopts = gnustep_platform_linkopts() + [
    ],
    deps = [
        "@giflib//:giflib",
        "@gnustep_base//:gnustep-base",
        "@icu//icu4c/source/common:platform",
        "@icu//icu4c/source/i18n:collation",
        "@libjpeg_turbo//:jpeg",
        "@libobjc2//:objc",
        "@libpng//:png",
        "@libtiff//:tiff",
    ],
)

objc_binary(
    name = "make_services",
    srcs = ["Tools/make_services.m"],
    deps = [
        ":gnustep-gui",
        "@gnustep_base//:gnustep-base",
        "@libobjc2//:objc",
    ],
)

objc_test(
    name = "nsaffinetransform_test",
    size = "small",
    srcs = ["Tests/gui/NSAffineTransform/basic.m"],
    deps = [
        ":gnustep-gui",
        "@gnustep_base//:gnustep-base",
        "@gnustep_make//:testing_h",
        "@libobjc2//:objc",
    ],
)
