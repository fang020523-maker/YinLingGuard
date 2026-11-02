# 银龄守护 YinLingGuard

**端云协同多模态感知的适老化健康守护系统** —— HarmonyOS 原生应用

> 第九届传智杯 · HarmonyOS Codelabs 挑战赛（AI 鸿蒙赛道）· 研究生组
> 队长 陈嘉浩 · 广东技术师范大学

## 项目简介

面向独居老人"**跌倒、用药、慢病**"三大风险，构建"**端侧隐私感知 + 云端智能决策 + 家人协同**"的守护闭环——传感与语音原始数据全程不出设备，仅结构化告警事件外发。

## 核心能力

| 能力 | 说明 |
|---|---|
| 🚨 端侧跌倒检测 | 加速度"冲击相+静止相"状态机 + **10 秒倒计时自救**（一键解除误报 / 无响应自动升级并系统通知家属） |
| 🗣️ 语音求救识别 | Core Speech Kit 端侧识别 + **求救词系统热词**（"救命/摔倒了"），覆盖传感器盲区与无法触屏场景 |
| 💊 多模态识药 | GLM-4V 拍照识药 → 自动生成联用安全问题 |
| 📚 向量 RAG 问答 | GLM embedding 语义召回 + 受控生成 + **知识来源可溯源**；断网三级降级 |
| 🤖 用药管家 Agent | ReAct 三步编排（规划→检索→生成），过程在对话流**可视化** |
| 📱 元服务卡片 | 家属桌面 2×2 守护状态实时卡片 |
| 🔄 分布式同步 | distributedKVStore 跨设备告警/健康同步（同账号可信组网） |

## 技术栈

HarmonyOS 7.0（API 26）· ArkTS / ArkUI（Stage 模型）· Sensor Kit / Core Speech Kit / Notification Kit / Form Kit / RelationalStore / distributedKVStore · 智谱 GLM（glm-4-flash / glm-4v-flash / embedding-2）

## 仓库目录说明

| 目录 / 文件 | 内容 |
|---|---|
| `YinLingGuard/` | 应用源码工程（目录名保留英文：HarmonyOS hvigor 构建系统要求工程路径为纯 ASCII 字符，中文路径会构建失败） |
| `文档/` | 参赛作品说明文档、性能实测与测试说明、联邦学习模拟图 |
| `银龄守护-演示视频.mp4` | 100 秒全流程演示（跌倒检测→倒计时自救→家属告警→RAG 问答→Agent→识药） |
| `银龄守护-讲解视频.mp4` | 3 分钟作品讲解 |

## 工程结构

```
entry/src/main/ets/
├── entryability/          # UIAbility 入口 + 权限申请
├── common/Theme.ets       # 适老化设计规范（大字号高对比双端主题）
├── model/Models.ets       # 领域模型
├── service/
│   ├── FallDetectService.ets    # 端侧跌倒检测状态机
│   ├── SosDetectService.ets     # 端侧语音求救（热词增强）
│   ├── LlmService.ets           # 向量 RAG + GLM-4V 识药（三级降级）
│   ├── AgentService.ets         # 用药管家多步编排
│   ├── DistributedSync.ets      # 分布式 KV 同步
│   ├── AlertDb.ets / GuardStore.ets / NotifyService.ets
├── entryformability/      # 元服务卡片
├── widget/                # 卡片 UI
└── pages/                 # 角色选择 / 老人端×3 / 家属端
```

## 快速体验

1. DevEco Studio（或 [DevEco CLI](https://developer.huawei.com/consumer/cn/deveco-studio/)）打开工程，签名后运行于 HarmonyOS 6+（API 20+）设备/模拟器；
2. 首次启动选择角色（老人/家属）；演示入口：【演示】模拟跌倒 / 模拟喊"救命" / 示例识药 / 用药管家；
3. 云端 AI 能力：在 `LlmService.ets` 填入[智谱开放平台](https://bigmodel.cn)免费 API Key（不填自动降级本地知识库模式，功能不中断）。

## 质量数据（实测）

- 冷启动（onCreate→首帧）**246ms** · 运行内存 RSS ≈ **37MB** · 14 项功能用例全部通过
- 联邦学习演进模拟（FedAvg，10 家庭数据不出户）：准确率 **80.8% → 85.9%**，逼近集中式上界 86.4%

## 演示

- 📹 演示视频（100 秒全流程）：https://www.bilibili.com/video/BV1tV4F6mEQj/
- 📹 讲解视频（3 分钟）：https://www.bilibili.com/video/BV1tV4F6mEQj/

## 声明

本项目为参赛原创作品。开发全流程使用 AI 辅助工具（华为 DevEco CLI 等），架构决策、功能设计与全部验证由团队完成。云能力依赖智谱 GLM 开放 API（本仓库已脱敏 Key）。

MIT License © 2026 陈嘉浩
