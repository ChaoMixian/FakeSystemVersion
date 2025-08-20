// clang++ -std=c++17 sysver.mm -framework Foundation -o sysver
// sysver.mm
#include <iostream>
#include <sys/utsname.h>
#include <sys/sysctl.h>

#import <Foundation/Foundation.h>

static std::string sysctl_string(const char* name) {
    size_t size = 0;
    if (sysctlbyname(name, nullptr, &size, nullptr, 0) != 0 || size == 0) {
        return "";
    }
    std::string s(size, '\0');
    if (sysctlbyname(name, s.data(), &size, nullptr, 0) != 0) {
        return "";
    }
    if (!s.empty() && s.back() == '\0') s.pop_back();
    return s;
}

int main() {
    // 1) NSProcessInfo（Cocoa 层）
    @autoreleasepool {
        NSProcessInfo *pi = [NSProcessInfo processInfo];
        NSOperatingSystemVersion v = [pi operatingSystemVersion];
        NSString *vs = [pi operatingSystemVersionString];
        std::cout << "[NSProcessInfo] operatingSystemVersionString: "
                  << [vs UTF8String] << "\n";
        std::cout << "[NSProcessInfo] components: "
                  << v.majorVersion << "." << v.minorVersion << "." << v.patchVersion << "\n";
    }

    // 2) sysctlbyname(kern.osproductversion)（内核导出）
    {
        std::string prod = sysctl_string("kern.osproductversion"); // e.g. 14.0 或 13.6.9
        std::cout << "[sysctl] kern.osproductversion: " << (prod.empty() ? "(unavailable)" : prod) << "\n";
    }

    // 3) uname()（Darwin 内核版本，不等于 macOS 产品版本）
    {
        utsname u{};
        if (uname(&u) == 0) {
            std::cout << "[uname] sysname=" << u.sysname
                      << " release=" << u.release
                      << " version=" << u.version
                      << " machine=" << u.machine << "\n";
        } else {
            std::cout << "[uname] failed\n";
        }
    }
    return 0;
}
