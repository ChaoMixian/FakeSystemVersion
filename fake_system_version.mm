// fake_system_version.mm
// 完全模拟 macOS 系统版本和 Darwin 内核版本
// 支持 NSProcessInfo、sysctlbyname、uname、SystemVersion.plist
// 
// 编译命令:
// clang++ -std=c++17 -dynamiclib fake_system_version.mm -o fake_system_version.dylib \
//     -framework Foundation -fobjc-arc
//
// 使用方法:
// DYLD_INSERT_LIBRARIES=./fake_system_version.dylib your_app

#include <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

// ===================================================================================
// 配置区域 - 所有自定义选项都在这里，支持环境变量覆盖
// ===================================================================================

struct SystemConfig {
    // === 系统版本配置 ===
    NSInteger major_version = 15;           // 主版本号 (可通过 FAKE_OS_MAJOR 环境变量覆盖)
    NSInteger minor_version = 4;            // 次版本号 (可通过 FAKE_OS_MINOR 环境变量覆盖)
    NSInteger patch_version = 1;            // 补丁版本号 (可通过 FAKE_OS_PATCH 环境变量覆盖)
    const char* build_version = "24E263";   // 系统构建版本 (可通过 FAKE_OS_BUILD 环境变量覆盖)
    
    // === Darwin 内核配置 ===
    const char* darwin_release = "24.4.0";  // Darwin 发布版本 (可通过 FAKE_KERNEL_RELEASE 环境变量覆盖)
    const char* darwin_version =             // Darwin 完整版本信息 (可通过 FAKE_KERNEL_VERSION 环境变量覆盖)
        "Darwin Kernel Version 24.4.0: Fri Apr 11 18:32:50 PDT 2025; "
        "root:xnu-11417.101.15~117/RELEASE_ARM64_T6041";
    
    // === 硬件架构配置 ===
    const char* machine_type = "arm64";     // 机器架构 (可通过 FAKE_MACHINE 环境变量覆盖)
    
    // === 硬件信息配置（默认不修改，设置为空字符串表示不hook） ===
    const char* hw_model = "";              // 硬件型号 (可通过 FAKE_HW_MODEL 环境变量覆盖，空表示不修改)
    const char* hw_machine = "";            // 机器架构 (可通过 FAKE_HW_MACHINE 环境变量覆盖，空表示不修改)
    const char* hw_memsize = "";            // 内存大小 (可通过 FAKE_HW_MEMSIZE 环境变量覆盖，空表示不修改)
    
    // === 功能开关 ===
    bool enable_logging = true;             // 是否启用日志输出 (可通过 FAKE_ENABLE_LOG=0 环境变量禁用)
    bool auto_product_name = true;          // 是否根据版本自动选择产品名称 (可通过 FAKE_AUTO_PRODUCT_NAME=0 环境变量禁用)
    
    // 根据版本号自动判断产品名称
    const char* get_product_name() const {
        if (!auto_product_name) {
            return "macOS";  // 默认使用 macOS
        }
        // macOS 11+ 使用 "macOS"，之前版本使用 "Mac OS X"
        return (major_version >= 11) ? "macOS" : "Mac OS X";
    }
    
    // 从环境变量加载配置
    void load_from_environment() {
        const char* env;
        
        // 系统版本配置
        if ((env = getenv("FAKE_OS_MAJOR"))) major_version = atol(env);
        if ((env = getenv("FAKE_OS_MINOR"))) minor_version = atol(env);
        if ((env = getenv("FAKE_OS_PATCH"))) patch_version = atol(env);
        if ((env = getenv("FAKE_OS_BUILD"))) build_version = env;
        
        // 兼容旧版本环境变量格式 (FAKE_OS_VERSION=15.4.1)
        if ((env = getenv("FAKE_OS_VERSION"))) {
            sscanf(env, "%ld.%ld.%ld", &major_version, &minor_version, &patch_version);
        }
        
        // Darwin 内核配置
        if ((env = getenv("FAKE_KERNEL_RELEASE"))) darwin_release = env;
        if ((env = getenv("FAKE_KERNEL_VERSION"))) darwin_version = env;
        
        // 硬件架构配置
        if ((env = getenv("FAKE_MACHINE"))) machine_type = env;
        
        // 硬件信息配置
        if ((env = getenv("FAKE_HW_MODEL"))) hw_model = env;
        if ((env = getenv("FAKE_HW_MACHINE"))) hw_machine = env;
        if ((env = getenv("FAKE_HW_MEMSIZE"))) hw_memsize = env;
        
        // 功能开关
        if ((env = getenv("FAKE_ENABLE_LOG"))) enable_logging = (strcmp(env, "0") != 0);
        if ((env = getenv("FAKE_AUTO_PRODUCT_NAME"))) auto_product_name = (strcmp(env, "0") != 0);
    }
};

// 全局配置实例
static SystemConfig g_config;

// ===================================================================================
// 日志系统
// ===================================================================================

// 日志输出函数，支持开关控制
static void logf(const char *fmt, ...) {
    if (!g_config.enable_logging) return;
    
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "[fake_system_version] ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
}

// ===================================================================================
// NSProcessInfo Hook - 拦截系统版本查询
// ===================================================================================

// 拦截 operatingSystemVersionString 方法
static NSString* fake_operatingSystemVersionString(id self, SEL _cmd) {
    logf("拦截 NSProcessInfo.operatingSystemVersionString (类: %s)", 
         class_getName(object_getClass(self)));
    
    return [NSString stringWithFormat:@"Version %ld.%ld.%ld (Build %s)",
            (long)g_config.major_version, 
            (long)g_config.minor_version, 
            (long)g_config.patch_version,
            g_config.build_version];
}

// 拦截 operatingSystemVersion 方法
static NSOperatingSystemVersion fake_operatingSystemVersion(id self, SEL _cmd) {
    logf("拦截 NSProcessInfo.operatingSystemVersion (类: %s)", 
         class_getName(object_getClass(self)));
    
    NSOperatingSystemVersion ver;
    ver.majorVersion = g_config.major_version;
    ver.minorVersion = g_config.minor_version;
    ver.patchVersion = g_config.patch_version;
    return ver;
}

// ===================================================================================
// sysctl Hook - 拦截底层系统调用
// ===================================================================================

// 保存原始 sysctl 函数指针
static int (*orig_sysctl)(int*, u_int, void*, size_t*, void*, size_t) = sysctl;

// 自定义的 sysctl 实现
extern "C" int my_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    // 拦截 hw.memsize (fastfetch 使用的方式)
    if (namelen == 2 && name[0] == CTL_HW && name[1] == HW_MEMSIZE) {
        if (strlen(g_config.hw_memsize) > 0) {
            logf("拦截 sysctl(CTL_HW, HW_MEMSIZE)");
            
            uint64_t fake_memsize = strtoull(g_config.hw_memsize, NULL, 10);
            
            if (oldlenp) {
                size_t required_len = sizeof(uint64_t);
                if (!oldp) {
                    *oldlenp = required_len;
                    return 0;
                }
                if (*oldlenp < required_len) {
                    // 返回 EFAULT 或其他错误可能更合适，但为了简单起见，我们遵循 sysctlbyname 的模式
                    return ENOMEM;
                }
                memcpy(oldp, &fake_memsize, required_len);
                *oldlenp = required_len;
                return 0;
            }
        }
    }
    
    // 其他情况调用原始函数
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

// 使用 __interpose 机制替换 sysctl
__attribute__((used))
static struct { 
    const void* replacement; 
    const void* replacee; 
} _interpose_sysctl_mib[] __attribute__((section("__DATA,__interpose"))) = {
    { (const void*)my_sysctl, (const void*)sysctl }
};


// ===================================================================================
// sysctlbyname Hook - 拦截系统调用
// ===================================================================================

// 保存原始 sysctlbyname 函数指针
static int (*orig_sysctlbyname)(const char*, void*, size_t*, void*, size_t) = sysctlbyname;

// 自定义的 sysctlbyname 实现
extern "C" int my_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (!name) {
        return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    }
    
    // === 系统版本相关的 sysctl ===
    if (strcmp(name, "kern.osproductversion") == 0) {
        logf("拦截 sysctlbyname('%s')", name);
        char fake_version[64];
        snprintf(fake_version, sizeof(fake_version), "%ld.%ld", 
                (long)g_config.major_version, (long)g_config.minor_version);
        
        if (oldlenp) {
            size_t required_len = strlen(fake_version) + 1;
            if (!oldp) {
                *oldlenp = required_len;
                return 0;
            }
            if (*oldlenp < required_len) {
                *oldlenp = required_len;
                return -1;
            }
            memcpy(oldp, fake_version, required_len);
            *oldlenp = required_len;
            return 0;
        }
    }
    else if (strcmp(name, "kern.osbuildversion") == 0) {
        logf("拦截 sysctlbyname('%s')", name);
        const char* fake_build = g_config.build_version;
        
        if (oldlenp) {
            size_t required_len = strlen(fake_build) + 1;
            if (!oldp) {
                *oldlenp = required_len;
                return 0;
            }
            if (*oldlenp < required_len) {
                *oldlenp = required_len;
                return -1;
            }
            memcpy(oldp, fake_build, required_len);
            *oldlenp = required_len;
            return 0;
        }
    }
    else if (strcmp(name, "kern.osrelease") == 0) {
        logf("拦截 sysctlbyname('%s')", name);
        const char* fake_release = g_config.darwin_release;
        
        if (oldlenp) {
            size_t required_len = strlen(fake_release) + 1;
            if (!oldp) {
                *oldlenp = required_len;
                return 0;
            }
            if (*oldlenp < required_len) {
                *oldlenp = required_len;
                return -1;
            }
            memcpy(oldp, fake_release, required_len);
            *oldlenp = required_len;
            return 0;
        }
    }
    // === 硬件架构相关的 sysctl ===
    else if (strcmp(name, "hw.machine") == 0) {
        // 如果配置了自定义的 hw.machine，则拦截
        if (strlen(g_config.hw_machine) > 0) {
            logf("拦截 sysctlbyname('%s')", name);
            const char* fake_machine = g_config.hw_machine;
            
            if (oldlenp) {
                size_t required_len = strlen(fake_machine) + 1;
                if (!oldp) {
                    *oldlenp = required_len;
                    return 0;
                }
                if (*oldlenp < required_len) {
                    *oldlenp = required_len;
                    return -1;
                }
                memcpy(oldp, fake_machine, required_len);
                *oldlenp = required_len;
                return 0;
            }
        }
    }
    else if (strcmp(name, "hw.model") == 0) {
        // 如果配置了自定义的 hw.model，则拦截
        if (strlen(g_config.hw_model) > 0) {
            logf("拦截 sysctlbyname('%s')", name);
            const char* fake_model = g_config.hw_model;
            
            if (oldlenp) {
                size_t required_len = strlen(fake_model) + 1;
                if (!oldp) {
                    *oldlenp = required_len;
                    return 0;
                }
                if (*oldlenp < required_len) {
                    *oldlenp = required_len;
                    return -1;
                }
                memcpy(oldp, fake_model, required_len);
                *oldlenp = required_len;
                return 0;
            }
        }
    }
    else if (strcmp(name, "hw.memsize") == 0) {
        // 如果配置了自定义的 hw.memsize，则拦截
        if (strlen(g_config.hw_memsize) > 0) {
            logf("拦截 sysctlbyname('%s')", name);
            // hw.memsize 是数值类型，需要特殊处理
            uint64_t fake_memsize = strtoull(g_config.hw_memsize, NULL, 10);
            
            if (oldlenp) {
                size_t required_len = sizeof(uint64_t);
                if (!oldp) {
                    *oldlenp = required_len;
                    return 0;
                }
                if (*oldlenp < required_len) {
                    *oldlenp = required_len;
                    return -1;
                }
                memcpy(oldp, &fake_memsize, required_len);
                *oldlenp = required_len;
                return 0;
            }
        }
    }
    
    // 其他情况调用原始函数
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// 使用 __interpose 机制替换 sysctlbyname
__attribute__((used))
static struct { 
    const void* replacement; 
    const void* replacee; 
} _interpose_sysctl[] __attribute__((section("__DATA,__interpose"))) = {
    { (const void*)my_sysctlbyname, (const void*)sysctlbyname }
};

// ===================================================================================
// uname Hook - 拦截系统信息查询
// ===================================================================================

// 保存原始 uname 函数指针
static int (*orig_uname)(struct utsname*) = uname;

// 自定义的 uname 实现
extern "C" int my_uname(struct utsname* buf) {
    logf("拦截 uname()");
    
    // 先调用原始函数获取真实信息
    int ret = orig_uname(buf);
    
    // 如果调用成功，则修改相关字段
    if (ret == 0 && buf) {
        // 修改 Darwin 发布版本
        strncpy(buf->release, g_config.darwin_release, sizeof(buf->release) - 1);
        buf->release[sizeof(buf->release) - 1] = '\0';
        
        // 修改 Darwin 完整版本信息
        strncpy(buf->version, g_config.darwin_version, sizeof(buf->version) - 1);
        buf->version[sizeof(buf->version) - 1] = '\0';
        
        // 修改机器架构类型
        strncpy(buf->machine, g_config.machine_type, sizeof(buf->machine) - 1);
        buf->machine[sizeof(buf->machine) - 1] = '\0';
        
        logf("已修改 uname 信息: release=%s, machine=%s", buf->release, buf->machine);
    }
    
    return ret;
}

// 使用 __interpose 机制替换 uname
__attribute__((used))
static struct { 
    const void* replacement; 
    const void* replacee; 
} _interpose_uname[] __attribute__((section("__DATA,__interpose"))) = {
    { (const void*)my_uname, (const void*)uname }
};

// ===================================================================================
// SystemVersion.plist Hook - 拦截系统版本文件读取
// ===================================================================================

// 保存原始函数指针
static id (*orig_dictWithContentsOfURLError)(id, SEL, NSURL*, NSError**) = nullptr;

// 拦截 NSDictionary 的 dictionaryWithContentsOfURL:error: 方法
static id fake_dictWithContentsOfURLError(id self, SEL _cmd, NSURL* url, NSError** error) {
    logf("拦截 NSDictionary.dictionaryWithContentsOfURL: %s", 
         url.absoluteString.UTF8String);

    // 检查是否是 SystemVersion.plist 文件
    if ([url.absoluteString hasSuffix:@"/System/Library/CoreServices/SystemVersion.plist"]) {
        logf("检测到 SystemVersion.plist 读取请求，返回伪造数据");

        // 创建伪造的系统版本信息字典
        NSMutableDictionary *fake_dict = [NSMutableDictionary dictionary];
        
        // 设置产品版本（用户可见版本）
        [fake_dict setObject:[NSString stringWithFormat:@"%ld.%ld",
                             (long)g_config.major_version, 
                             (long)g_config.minor_version]
                      forKey:@"ProductUserVisibleVersion"];
        
        // 设置完整产品版本
        [fake_dict setObject:[NSString stringWithFormat:@"%ld.%ld.%ld",
                             (long)g_config.major_version, 
                             (long)g_config.minor_version, 
                             (long)g_config.patch_version]
                      forKey:@"ProductVersion"];
        
        // 设置构建版本
        [fake_dict setObject:[NSString stringWithUTF8String:g_config.build_version]
                      forKey:@"ProductBuildVersion"];
        
        // 设置产品名称（根据版本自动判断或使用固定值）
        [fake_dict setObject:[NSString stringWithUTF8String:g_config.get_product_name()]
                      forKey:@"ProductName"];
        
        // 设置产品版权信息
        [fake_dict setObject:@"1983-2024 Apple Inc."
                      forKey:@"ProductCopyright"];
        
        logf("返回伪造的 SystemVersion.plist: %s %ld.%ld.%ld (%s)", 
             g_config.get_product_name(),
             (long)g_config.major_version, 
             (long)g_config.minor_version, 
             (long)g_config.patch_version,
             g_config.build_version);
        
        return fake_dict;
    }

    // 其他 URL 调用原始函数
    if (orig_dictWithContentsOfURLError) {
        return orig_dictWithContentsOfURLError(self, _cmd, url, error);
    }

    // 如果原始函数不可用，返回错误
    if (error) {
        *error = [NSError errorWithDomain:@"fake_system_version" 
                                     code:-1 
                                 userInfo:@{NSLocalizedDescriptionKey: @"Original method not available"}];
    }
    return nil;
}

// ===================================================================================
// Hook 安装和自检系统
// ===================================================================================

// 检查 sysctl 和 sysctlbyname hook 是否工作正常
static void verify_sysctl_hooks() {
    char buffer[256];
    size_t buffer_len;
    
    // --- 检查 sysctlbyname ---
    // 检查 kern.osproductversion
    buffer_len = sizeof(buffer);
    if (my_sysctlbyname("kern.osproductversion", buffer, &buffer_len, NULL, 0) == 0) {
        char expected[64];
        snprintf(expected, sizeof(expected), "%ld.%ld", 
                (long)g_config.major_version, (long)g_config.minor_version);
        if (strcmp(buffer, expected) == 0) {
            logf("✓ sysctlbyname('kern.osproductversion') hook 工作正常");
        } else {
            logf("✗ sysctlbyname('kern.osproductversion') hook 可能失败: 期望=%s, 实际=%s", 
                 expected, buffer);
        }
    }
    
    // 检查 kern.osbuildversion
    buffer_len = sizeof(buffer);
    if (my_sysctlbyname("kern.osbuildversion", buffer, &buffer_len, NULL, 0) == 0) {
        if (strcmp(buffer, g_config.build_version) == 0) {
            logf("✓ sysctlbyname('kern.osbuildversion') hook 工作正常");
        } else {
            logf("✗ sysctlbyname('kern.osbuildversion') hook 可能失败: 期望=%s, 实际=%s", 
                 g_config.build_version, buffer);
        }
    }
    
    // 检查 kern.osrelease
    buffer_len = sizeof(buffer);
    if (my_sysctlbyname("kern.osrelease", buffer, &buffer_len, NULL, 0) == 0) {
        if (strcmp(buffer, g_config.darwin_release) == 0) {
            logf("✓ sysctlbyname('kern.osrelease') hook 工作正常");
        } else {
            logf("✗ sysctlbyname('kern.osrelease') hook 可能失败: 期望=%s, 实际=%s", 
                 g_config.darwin_release, buffer);
        }
    }
    
    // --- 检查 sysctl ---
    if (strlen(g_config.hw_memsize) > 0) {
        uint64_t memsize_val;
        size_t memsize_len = sizeof(memsize_val);
        int mib[] = {CTL_HW, HW_MEMSIZE};
        if (my_sysctl(mib, 2, &memsize_val, &memsize_len, NULL, 0) == 0) {
            uint64_t expected_memsize = strtoull(g_config.hw_memsize, NULL, 10);
            if (memsize_val == expected_memsize) {
                 logf("✓ sysctl(HW_MEMSIZE) hook 工作正常");
            } else {
                 logf("✗ sysctl(HW_MEMSIZE) hook 可能失败: 期望=%llu, 实际=%llu", expected_memsize, memsize_val);
            }
        }
    }
}

// 检查 uname hook 是否工作正常
static void verify_uname_hook() {
    struct utsname uname_buf;
    if (my_uname(&uname_buf) == 0) {
        bool release_ok = (strcmp(uname_buf.release, g_config.darwin_release) == 0);
        bool version_ok = (strcmp(uname_buf.version, g_config.darwin_version) == 0);
        bool machine_ok = (strcmp(uname_buf.machine, g_config.machine_type) == 0);
        
        if (release_ok && version_ok && machine_ok) {
            logf("✓ uname() hook 工作正常");
        } else {
            logf("✗ uname() hook 可能失败:");
            if (!release_ok) logf("  release: 期望=%s, 实际=%s", g_config.darwin_release, uname_buf.release);
            if (!version_ok) logf("  version: 期望=%s, 实际=%s", g_config.darwin_version, uname_buf.version);
            if (!machine_ok) logf("  machine: 期望=%s, 实际=%s", g_config.machine_type, uname_buf.machine);
        }
    }
}

// 输出当前配置信息
static void print_configuration() {
    logf("=== fake_system_version 配置信息 ===");
    logf("系统版本: %ld.%ld.%ld (Build %s)", 
         (long)g_config.major_version, 
         (long)g_config.minor_version, 
         (long)g_config.patch_version,
         g_config.build_version);
    logf("Darwin 版本: %s", g_config.darwin_release);
    logf("机器架构: %s", g_config.machine_type);
    logf("产品名称: %s (自动判断: %s)", 
         g_config.get_product_name(),
         g_config.auto_product_name ? "启用" : "禁用");
    
    if (strlen(g_config.hw_model) > 0) {
        logf("硬件型号: %s", g_config.hw_model);
    }
    if (strlen(g_config.hw_machine) > 0) {
        logf("硬件机器类型: %s", g_config.hw_machine);
    }
    if (strlen(g_config.hw_memsize) > 0) {
        logf("内存大小: %s", g_config.hw_memsize);
    }
    
    logf("日志输出: %s", g_config.enable_logging ? "启用" : "禁用");
    logf("=====================================");
}

// ===================================================================================
// 构造函数 - 初始化所有 Hook
// ===================================================================================

// 安装 NSProcessInfo Hook
__attribute__((constructor))
static void install_hooks() {
    // 从环境变量加载配置
    g_config.load_from_environment();
    
    logf("fake_system_version 动态库已加载");
    print_configuration();

    // 查找 NSProcessInfo 类（优先使用 Swift 版本）
    Class process_info_class = objc_getClass("_NSSwiftProcessInfo");
    if (!process_info_class) {
        process_info_class = [NSProcessInfo class];
    }

    // Hook operatingSystemVersionString 方法
    Method version_string_method = class_getInstanceMethod(process_info_class, 
                                                          @selector(operatingSystemVersionString));
    if (version_string_method) {
        method_setImplementation(version_string_method, 
                               (IMP)fake_operatingSystemVersionString);
        
        // 验证 Hook 是否成功
        if (method_getImplementation(version_string_method) == (IMP)fake_operatingSystemVersionString) {
            logf("✓ NSProcessInfo.operatingSystemVersionString hook 安装成功");
        } else {
            logf("✗ NSProcessInfo.operatingSystemVersionString hook 安装失败");
        }
    }

    // Hook operatingSystemVersion 方法
    Method version_method = class_getInstanceMethod(process_info_class, 
                                                   @selector(operatingSystemVersion));
    if (version_method) {
        method_setImplementation(version_method, 
                               (IMP)fake_operatingSystemVersion);
        
        // 验证 Hook 是否成功
        if (method_getImplementation(version_method) == (IMP)fake_operatingSystemVersion) {
            logf("✓ NSProcessInfo.operatingSystemVersion hook 安装成功");
        } else {
            logf("✗ NSProcessInfo.operatingSystemVersion hook 安装失败");
        }
    }

    // 执行自检
    verify_sysctl_hooks();
    verify_uname_hook();
}

// 安装 SystemVersion.plist Hook
__attribute__((constructor))
static void install_systemversion_plist_hook() {
    logf("正在安装 SystemVersion.plist hook...");

    // 获取 NSDictionary 类
    Class dict_class = objc_getClass("NSDictionary");
    if (!dict_class) {
        dict_class = [NSDictionary class];
    }

    // Hook dictionaryWithContentsOfURL:error: 类方法
    Method dict_method = class_getClassMethod(dict_class, 
                                             @selector(dictionaryWithContentsOfURL:error:));
    if (dict_method) {
        // 保存原始实现
        orig_dictWithContentsOfURLError = (id(*)(id, SEL, NSURL*, NSError**))
                                         method_getImplementation(dict_method);
        
        // 替换为自定义实现
        method_setImplementation(dict_method, (IMP)fake_dictWithContentsOfURLError);

        // 验证 Hook 是否成功
        if (method_getImplementation(dict_method) == (IMP)fake_dictWithContentsOfURLError) {
            logf("✓ NSDictionary.dictionaryWithContentsOfURL:error: hook 安装成功");
        } else {
            logf("✗ NSDictionary.dictionaryWithContentsOfURL:error: hook 安装失败");
        }
    } else {
        logf("✗ 无法找到 NSDictionary.dictionaryWithContentsOfURL:error: 方法");
    }
}