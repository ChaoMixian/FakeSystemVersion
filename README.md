# FakeSystemVersion

FakeSystemVersion 是一个用于 macOS 的动态库，它允许用户动态地修改应用程序获取到的系统版本、内核版本以及硬件信息。通过 `DYLD_INSERT_LIBRARIES` 机制，它可以在不修改目标应用程序二进制文件的情况下，拦截并伪造系统调用和 Objective-C 方法的返回值，从而实现对系统信息的“欺骗”。

这对于在特定系统版本的应用兼容性测试、软件行为分析或绕过某些应用的强制更新限制等场景非常有用。

## ✨ 功能特性

* **全面的信息伪造**:
    * **Cocoa/Foundation 层**: 拦截 `NSProcessInfo` 的 `operatingSystemVersion` 和 `operatingSystemVersionString` 方法。
    * **BSD/sysctl 层**: 拦截 `sysctl` 和 `sysctlbyname` 调用，伪造 `kern.osproductversion`, `kern.osbuildversion`, `kern.osrelease` 等内核信息，以及 `hw.model`, `hw.machine`, `hw.memsize` 等硬件信息。
    * **uname**: 拦截 `uname()` 系统调用，修改 Darwin 内核版本 (`release`, `version`) 和机器架构 (`machine`)。
    * **配置文件**: 拦截对 `/System/Library/CoreServices/SystemVersion.plist` 文件的读取，返回伪造的版本信息字典。
* **高度可配置**:
    * 通过命令行参数或环境变量，可以轻松设置主、次、补丁版本号，以及系统构建版本号。
    * 支持自定义 Darwin 内核版本字符串和硬件信息（如型号、架构、内存大小）。
    * 可切换日志输出，方便调试。
* **智能产品名称**: 可根据设置的系统主版本号自动判断产品名称是 "macOS" (>= 11) 还是 "Mac OS X" (< 11)。
* **易于使用**: 提供 `cli.sh` 命令行工具，简化了环境变量的设置和目标程序的启动过程。

## 🛠️ 如何编译

你需要一个支持 C++17 的编译器（如系统自带的 clang++）。在终端中执行以下命令来编译动态库：

```bash
clang++ -std=c++17 -dynamiclib fake_system_version.mm -o fake_system_version.dylib \
    -framework Foundation -fobjc-arc
```

## 🚀 使用方法

项目提供了一个便捷的命令行脚本 `cli.sh` 来加载动态库并执行你的目标程序。

### 基本用法

最简单的用法是指定一个伪造的系统版本，然后 `--` 后面跟上你要执行的命令。

例如，让 `sw_vers` 命令显示一个伪造的系统版本 `15.4.1`：

```bash
./cli.sh --os-version 15.4.1 -- sw_vers
```

### 高级用法

你可以通过各种参数详细地配置伪造的系统和硬件信息。

```bash
./cli.sh \
--os-version 15.4.1 \
--os-major 15 \
--os-minor 4 \
--os-patch 1 \
--build-version 24E263 \
--kernel-release 24.4.0 \
--kernel-version "Darwin Kernel Version 24.4.0: Fri Apr 11 18:32:50 PDT 2025; root:xnu-11417.101.15~117/RELEASE_ARM64_T6041" \
--machine arm64 \
--hw-model "MacBookAir10,1" \
--hw-machine arm64 \
--hw-memsize 17179869184 \
--enable-log \
--auto-product-name \
-- fastfetch
```

### 命令行选项

以下是 `cli.sh` 支持的所有选项：

| 选项                   | 描述                               | 环境变量                     |
| :--------------------- | :--------------------------------- | :--------------------------- |
| **系统版本** |                                    |                              |
| `--os-version VERSION` | 设置完整版本号 (如: 15.4.1)        | `FAKE_OS_VERSION`            |
| `--os-major MAJOR`     | 设置主版本号 (如: 15)              | `FAKE_OS_MAJOR`              |
| `--os-minor MINOR`     | 设置次版本号 (如: 4)               | `FAKE_OS_MINOR`              |
| `--os-patch PATCH`     | 设置补丁版本号 (如: 1)             | `FAKE_OS_PATCH`              |
| `--build-version BUILD`| 设置构建版本 (如: 24E263)          | `FAKE_OS_BUILD`              |
| **Darwin 内核** |                                    |                              |
| `--kernel-release REL` | 设置内核发布版本 (如: 24.4.0)      | `FAKE_KERNEL_RELEASE`        |
| `--kernel-version VER` | 设置完整内核版本字符串             | `FAKE_KERNEL_VERSION`        |
| **硬件架构** |                                    |                              |
| `--machine ARCH`       | 修改 `uname` 返回的机器架构        | `FAKE_MACHINE`               |
| **硬件信息** |                                    |                              |
| `--hw-model MODEL`     | 修改 `sysctl` 的 `hw.model` 返回值 | `FAKE_HW_MODEL`              |
| `--hw-machine MACHINE` | 修改 `sysctl` 的 `hw.machine` 返回值| `FAKE_HW_MACHINE`            |
| `--hw-memsize SIZE`    | 设置内存大小 (单位: 字节)          | `FAKE_HW_MEMSIZE`            |
| **功能开关** |                                    |                              |
| `--enable-log`         | 启用日志输出 (默认)                | `FAKE_ENABLE_LOG=1`          |
| `--disable-log`        | 禁用日志输出                       | `FAKE_ENABLE_LOG=0`          |
| `--auto-product-name`  | 自动判断产品名称 (默认)            | `FAKE_AUTO_PRODUCT_NAME=1`   |
| `--no-auto-product-name`| 禁用自动产品名称判断               | `FAKE_AUTO_PRODUCT_NAME=0`   |
| **其他** |                                    |                              |
| `-h`, `--help`         | 显示帮助信息                       |                              |
| `--`                  | 标记选项结束，后面是目标程序       |                              |

**注意**: `machine` 不同于 `hw-machine`，前者修改 `uname` 返回值，后者 hook 了 `sysctl` 的 `hw.machine` 返回值。 像 `fastfetch` 这样的工具通常使用前者。

## ✅ 如何验证

项目内提供了一个 `sysver` 测试程序，它可以从多个层面获取系统版本信息。 你可以用它来验证伪造成果。

首先，编译测试程序：

```bash
clang++ -std=c++17 sysver.mm -framework Foundation -o sysver
```

然后，不使用 hook 直接运行，查看真实信息：

```bash
./sysver
```

接着，使用 `cli.sh` 加载 hook 后运行，查看伪造信息：

```bash
./cli.sh --os-version 114.5.14 --build-version 1919810 -- ./sysver
```

通过对比两次的输出，你可以清晰地看到 `NSProcessInfo`, `sysctl`, 和 `uname` 的返回值都已经被成功修改。
