# ToDay HarmonyOS 真机签名接入

当前工程默认可以直接编译并装到模拟器，但要装到你自己的 `Mate 70` 和 `Watch GT 5`，还需要把华为开发者证书材料接进来。

## 需要准备的材料

- `.p12` 证书库文件
- `.cer` 应用证书文件
- `.p7b` profile 文件
- 证书库密码
- 密钥密码
- key alias

## 工程里已经放好的模板

- [`signing/build-profile.signing-template.json5`](/Users/looanli/Projects/ToDay/harmonyos/ToDay/signing/build-profile.signing-template.json5)

这个模板不会自动参与构建，只是给你填真实证书时直接对照。

## 接入方法

1. 把你的签名材料放进 [`signing`](/Users/looanli/Projects/ToDay/harmonyos/ToDay/signing)
2. 打开 [`build-profile.json5`](/Users/looanli/Projects/ToDay/harmonyos/ToDay/build-profile.json5)
3. 参考模板，把 `app.signingConfigs` 和 `products[0].signingConfig` 填进去
4. 路径建议都用相对项目根目录的写法，例如 `./signing/ToDay-release.p12`
5. 重新执行 `assembleApp`

## 当前模板里的关键字段

- `type`: 建议保持 `HarmonyOS`
- `material.storeFile`: `.p12` 路径
- `material.storePassword`: 证书库密码
- `material.keyAlias`: 密钥别名
- `material.keyPassword`: 密钥密码
- `material.certpath`: `.cer` 路径
- `material.profile`: `.p7b` 路径
- `material.signAlg`: 当前模板用 `SHA256withECDSA`

## 结果

签名补好后，你可以直接在 DevEco Studio 或命令行安装到真机：

```bash
'/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc' install -r /Users/looanli/Projects/ToDay/harmonyos/ToDay/entry/build/default/outputs/default/app/entry-default.hap
```

手表模块编译后会额外生成 `wear` 的 hap，后续也可以用同一套签名材料安装。
