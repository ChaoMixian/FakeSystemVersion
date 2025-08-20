## 基础功能演示

```bash
./cli.sh -- ./sysver

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
-- ./sysver

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

# 禁用日志
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
--disable-log \
--auto-product-name \
-- fastfetch
```
需要注意点：machine不同于hw-machine，前者修改uname返回值，后者hook了sysctl的hw-machine返回值
(fastfetch使用的是前者)
```bash
./cli.sh \
--machine machine \
--hw-machine hw-machine \
-- fastfetch
```

```bash
./cli.sh \
--os-version 15.4.1 \
-- /Applications/App\ Cleaner\ 8.app/Contents/MacOS/App\ Cleaner\ 8

./cli.sh \
--os-version 114514.1919810 \
-- /Applications/App\ Cleaner\ 8.app/Contents/MacOS/App\ Cleaner\ 8

# 使用中文或其他内容导致错误，会fallback到默认的15.4.1

```



