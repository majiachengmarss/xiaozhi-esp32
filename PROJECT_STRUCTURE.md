# xiaozhi-esp32 项目结构全解析

> 项目地址: https://github.com/78/xiaozhi-esp32  
> 版本: v2.2.6  
> 语言: C++  
> 简介: 基于 ESP32 的开源 AI 语音聊天机器人固件，通过 MCP 协议实现多端控制

---

## 整体架构图

```
                        ┌─────────────────────┐
                        │    OTA 服务器         │
                        └──────┬──────────────┘
                               │ HTTP
┌──────────────────────────────────────────────────────────────────────┐
│  ESP32 固件                                                          │
│                                                                      │
│  ┌────────┐  ┌──────────┐  ┌───────────┐  ┌──────────────────────┐  │
│  │ Board  │  │  Audio   │  │ Protocol  │  │      MCP Server      │  │
│  │ 硬件抽象│◄─┤ Service  │◄─┤ (MQTT/   │◄─┤ (JSON-RPC 2.0       │  │
│  │        │  │ OPUS编解码│  │  WebSock) │  │  本地工具执行)       │  │
│  └───┬────┘  └──────────┘  └─────┬─────┘  └──────────────────────┘  │
│      │                           │                                    │
│  ┌───┴────┐                 ┌────┴─────┐                             │
│  │Display │                 │ Network  │                             │
│  │LVGL    │                 │WiFi/4G   │                             │
│  └────────┘                 └──────────┘                             │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Application (事件循环 + 状态机)                                  │ │
│  │  空闲 → 连接中 → 聆听 → 说话 → 空闲    (含升级/激活等状态)       │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │   云端 AI 服务       │
                    │   ASR + LLM + TTS   │
                    │   + 声纹识别 + MCP   │
                    └─────────────────────┘
```

---

## 一、目录树总览

```
xiaozhi-esp32/
├── CMakeLists.txt               # 根构建文件, 项目版本 2.2.6
├── LICENSE                      # MIT 许可证
├── README.md / README_zh.md     # 项目文档 (英文/中文/日文)
│
├── .github/workflows/
│   └── build.yml                # CI: push/PR 时构建所有板子变体
│
├── main/                        # 核心固件源码 (C++)
│   ├── CMakeLists.txt           # 构建配置 (源文件/板子/资源/语言)
│   ├── Kconfig.projbuild        # ESP-IDF menuconfig 配置菜单
│   ├── idf_component.yml        # ESP 组件注册表依赖 (~60+ 组件)
│   │
│   ├── main.cc                  # 入口: app_main()
│   ├── application.cc/.h        # Application 单例 + 事件循环 + 状态机
│   ├── device_state.h           # 11 种设备状态枚举
│   ├── device_state_machine.cc/.h # 状态机 + 观察者模式
│   ├── ota.cc/.h                # OTA 固件升级
│   ├── mcp_server.cc/.h         # 设备端 MCP 协议服务
│   ├── settings.cc/.h           # NVS 键值存储
│   ├── system_info.cc/.h        # 系统信息收集
│   ├── assets.cc/.h             # 资源分区管理
│   │
│   ├── audio/                   # 音频子系统
│   │   ├── audio_codec.h/.cc    # 抽象音频编解码器基类
│   │   ├── audio_service.h/.cc  # 核心调度器 (3个FreeRTOS任务, 4个队列)
│   │   ├── audio_processor.h    # 抽象音频前端处理接口
│   │   ├── wake_word.h          # 抽象唤醒词检测接口
│   │   ├── codecs/              # 7种音频芯片驱动
│   │   │   ├── box_audio_codec.cc      # ESP-BOX 系列 (ES8311+ES7210)
│   │   │   ├── es8311_audio_codec.cc   # ES8311 单芯片
│   │   │   ├── es8374_audio_codec.cc   # ES8374
│   │   │   ├── es8388_audio_codec.cc   # ES8388
│   │   │   ├── es8389_audio_codec.cc   # ES8389
│   │   │   ├── no_audio_codec.cc       # 直连 I2S (无外部芯片)
│   │   │   └── dummy_audio_codec.cc    # 测试桩
│   │   ├── processors/          # AFE 音频前端处理
│   │   │   ├── afe_audio_processor.cc  # AFE (AEC + VAD + 降噪)
│   │   │   ├── no_audio_processor.cc   # 透传处理器
│   │   │   └── audio_debugger.cc       # UDP 调试输出
│   │   ├── wake_words/          # 唤醒词实现
│   │   │   ├── afe_wake_word.cc        # WakeNet+AFE (S3/P4)
│   │   │   ├── custom_wake_word.cc     # MultiNet 自定义唤醒词 (S3/P4)
│   │   │   └── esp_wake_word.cc        # 基础 WakeNet (C3/C5/C6)
│   │   └── demuxer/             # OGG 解复用器
│   │       └── ogg_demuxer.cc
│   │
│   ├── boards/                  # 70+ 开发板支持
│   │   ├── common/              # 公共基础设施
│   │   │   ├── board.h/.cc             # Board 抽象基类 + DECLARE_BOARD 宏
│   │   │   ├── wifi_board.h/.cc        # WiFi 板子基类
│   │   │   ├── ml307_board.h/.cc       # ML307 4G Cat.1 板子基类
│   │   │   ├── nt26_board.h/.cc        # NT26 4G 板子基类
│   │   │   ├── dual_network_board.h    # WiFi + 4G 双网络板子
│   │   │   ├── button.h/.cc            # GPIO 按钮 (单击/双击/长按)
│   │   │   ├── knob.h/.cc              # 旋转编码器
│   │   │   ├── backlight.h/.cc         # PWM 背光控制
│   │   │   ├── adc_battery_monitor.h   # ADC 电池检测
│   │   │   ├── axp2101.h/.cc           # AXP2101 电源管理芯片
│   │   │   ├── sy6970.h/.cc            # SY6970 电池充电芯片
│   │   │   ├── power_save_timer.h      # 省电模式定时器
│   │   │   ├── sleep_timer.h           # 深度睡眠定时器
│   │   │   ├── system_reset.h          # 系统复位
│   │   │   ├── camera.h                # 摄像头抽象
│   │   │   ├── esp_video.h/.cc         # EspVideo (P4/S3 视频输入)
│   │   │   ├── esp32_camera.h/.cc      # ESP32-Camera (OV2640等)
│   │   │   ├── rndis_board.h/.cc       # RNDIS USB 网络
│   │   │   ├── afsk_demod.h/.cc        # AFSK 解调 (声波配网)
│   │   │   ├── blufi.h/.cc             # BLuFi BLE 配网
│   │   │   ├── lamp_controller.h       # GPIO 灯 MCP 演示
│   │   │   └── press_to_talk_mcp_tool.h # 按键说话 MCP 工具
│   │   │
│   │   ├── esp-box-3/            # 乐鑫 ESP32-S3-BOX3
│   │   ├── bread-compact-wifi/   # 面包板 WiFi 版
│   │   ├── bread-compact-ml307/  # 面包板 4G 版 (ML307)
│   │   ├── bread-compact-nt26/   # 面包板 4G 版 (NT26)
│   │   ├── bread-compact-esp32/  # 面包板 ESP32 原版
│   │   ├── m5stack-core-s3/      # M5Stack CoreS3
│   │   ├── m5stack-cardputer-adv/ # M5Stack Cardputer
│   │   ├── m5stack-stack-s3/     # M5Stack Stack S3
│   │   ├── magiclick-2p4/        # 神奇按钮 2.4
│   │   ├── magiclick-c3/         # 神奇按钮 C3
│   │   ├── waveshare/            # 微雪电子系列
│   │   ├── lilygo-t-circle-s3/   # LilyGO T-Circle-S3
│   │   ├── xingzhi-cube-*/       # 星智 Cube 系列
│   │   ├── atk-dnesp32s3*/       # 正点原子系列
│   │   ├── sensecap-watcher/     # Seeed SenseCAP Watcher
│   │   └── ... (68+ 板子)       # 每个板子 = config.h + board.cc + config.json
│   │
│   ├── display/                  # 显示子系统
│   │   ├── display.h/.cc         # 抽象 Display 基类
│   │   ├── oled_display.h/.cc    # OLED 单色屏 (SSD1306/SH1106)
│   │   ├── lcd_display.h/.cc     # SPI 彩色 LCD
│   │   ├── emote_display.h/.cc   # Emote 动画风格显示
│   │   └── lvgl_display/         # LVGL 9.5 显示驱动
│   │       ├── lvgl_display.h/.cc        # LVGL 驱动集成
│   │       ├── lvgl_font.h/.cc           # 字体管理 + Font Awesome 图标
│   │       ├── lvgl_theme.h/.cc          # 浅色/深色主题切换
│   │       ├── lvgl_image.h/.cc          # 图片加载
│   │       ├── emoji_collection.h/.cc    # 表情管理
│   │       ├── gif/                      # GIF 解码器
│   │       └── jpg/                      # JPEG 编解码桥接
│   │
│   ├── led/                      # LED 子系统
│   │   ├── led.h                 # 抽象基类 + NoLed
│   │   ├── single_led.h/.cc      # WS2812 单灯 (颜色随状态变化)
│   │   ├── circular_strip.h/.cc  # 环形 LED 灯带
│   │   └── gpio_led.h/.cc        # 简单 GPIO 开关 LED
│   │
│   ├── protocols/                # 通信协议
│   │   ├── protocol.h/.cc        # 抽象 Protocol 基类 + BinaryProtocol2/3 帧格式
│   │   ├── mqtt_protocol.h/.cc   # MQTT 信令 + UDP 音频 (AES加密)
│   │   └── websocket_protocol.h/.cc # WebSocket 信令 + 音频
│   │
│   └── assets/                   # 内置资源
│       ├── common/               # 公共音效 (5个 .ogg 文件)
│       └── locales/              # ~40 种语言
│           ├── en-US/language.json
│           ├── zh-CN/language.json
│           └── ...               # ar-SA 到 ja-JP 全覆盖
│
├── partitions/                   # Flash 分区表
│   ├── v1/                       # 旧版 v1 (含 model 分区)
│   └── v2/                       # 当前 v2 (含 assets 分区)
│       ├── 4m.csv / 8m.csv / 16m.csv / 32m.csv
│       ├── 16m_c3.csv            # ESP32-C3 优化版
│       └── README.md
│
├── scripts/                      # 构建/发布/调试脚本
│   ├── release.py                # CI 构建编排器
│   ├── build_default_assets.py   # 资源二进制生成器
│   ├── gen_lang.py               # 语言配置头文件生成
│   ├── versions.py               # 版本管理
│   ├── download_github_runs.py   # 下载 CI 构建产物
│   ├── audio_debug_server.py     # UDP 音频调试服务
│   ├── mp3_to_ogg.sh             # 音频格式转换
│   ├── sonic_wifi_config.html    # 声波 WiFi 配网页面
│   ├── acoustic_check/           # 声波配网分析工具
│   ├── Image_Converter/          # LVGL 图片格式转换 GUI
│   ├── ogg_converter/            # OGG 音频转换器
│   ├── p3_tools/                 # P3 音频格式工具
│   └── spiffs_assets/            # SPIFFS 资源打包器
│
├── docs/                         # 文档
│   ├── custom-board.md / _zh.md  # 如何添加新板子
│   ├── mcp-protocol.md / _zh.md  # MCP 设备端协议规范
│   ├── mcp-usage.md / _zh.md     # MCP IoT 控制使用指南
│   ├── websocket.md / _zh.md     # WebSocket 通信协议
│   ├── mqtt-udp.md / _zh.md      # MQTT+UDP 混合协议
│   ├── blufi.md / _zh.md         # BLuFi BLE 配网
│   ├── code_style.md / _zh.md    # C++ 编码规范 (Google Style)
│   ├── v1/                       # v1 板子照片
│   └── v0/                       # v0 板子照片
│
├── sdkconfig.defaults            # 全局 SDK 默认配置
├── sdkconfig.defaults.esp32      # ESP32 专属配置
├── sdkconfig.defaults.esp32c3    # ESP32-C3 专属配置
├── sdkconfig.defaults.esp32c5    # ESP32-C5 专属配置
├── sdkconfig.defaults.esp32c6    # ESP32-C6 专属配置
├── sdkconfig.defaults.esp32s3    # ESP32-S3 专属配置
└── sdkconfig.defaults.esp32p4    # ESP32-P4 专属配置
```

---

## 二、启动流程

### 入口函数 app_main() [main.cc]

```
app_main()
  └─ nvs_flash_init()               // 1. 初始化 NVS (存储WiFi凭据等)
  └─ Application::GetInstance()     // 2. 获取单例 (创建事件组 + 时钟定时器)
  └─ app.Initialize()               // 3. 初始化所有子系统
  └─ app.Run()                      // 4. 事件循环 (永不返回)
```

### Initialize() 初始化顺序 [application.cc]

```
1. Board::GetInstance()             → 通过 DECLARE_BOARD 宏创建板级对象
2. SetDeviceState(Starting)         → 设置设备状态为"启动中"
3. display->SetupUI()              → 初始化屏幕, 显示启动信息
4. audio_service_.Initialize()     → 初始化 OPUS 编解码器 + 重采样器 + AFE
5. audio_service_.Start()          → 启动 3 个音频 FreeRTOS 任务
6. 注册音频回调:
   ├── on_send_queue_available     → 发送队列可用时通知
   ├── on_wake_word_detected       → 检测到唤醒词
   └── on_vad_change               → VAD 状态变化
7. state_machine_.AddListener()    → 状态变化 → 更新 LED + 屏幕表情
8. mcp_server.AddCommonTools()     → 注册 MCP 通用工具 (音量/亮度/相机)
9. mcp_server.AddUserOnlyTools()   → 注册仅用户可调用的 MCP 工具 (重启/升级)
10. board.SetNetworkEventCallback() → 网络事件 → UI 更新
11. board.StartNetwork()           → 异步启动 WiFi 或 4G 网络
```

### Run() 事件循环 [application.cc]

处理 13 种 FreeRTOS 事件:

| 事件 | 行为 |
|------|------|
| `NETWORK_CONNECTED` | 检查 OTA 版本 → 激活 → 建立 MQTT/WebSocket |
| `NETWORK_DISCONNECTED` | 关闭音频通道 |
| `TOGGLE_CHAT` | 空闲 ↔ 聆听 ↔ 说话 切换 |
| `START_LISTENING` | 开始 VAD + OPUS 编码 + 发送音频流 |
| `STOP_LISTENING` | 停止语音处理 |
| `WAKE_WORD_DETECTED` | 打开音频通道, 编码并发送唤醒词数据 |
| `VAD_CHANGE` | 更新 LED 状态 |
| `SEND_AUDIO` | 从发送队列取 OPUS 包, 通过协议发送 |
| `CLOCK_TICK` | 每秒更新状态栏 (电量/时间/信号) |
| `STATE_CHANGED` | 更新 LED 颜色 + 屏幕表情 |
| `ACTIVATION_DONE` | 显示版本号, 播放成功音效 |
| `ERROR` | 回到空闲状态, 显示告警 |

---

## 三、核心子系统详解

### 3.1 音频链路 (最重要)

```
麦克风
  ↓
I2S DMA
  ↓
AudioProcessor (AFE: AEC回声消除 / 降噪 / VAD语音活动检测)
  ↓
├── [空闲态] → 唤醒词检测 (离线本地运行, 不联网)
│      ↓ (检测到唤醒词)
│   打开音频通道
│
└── [聆听态] → VAD 分段 + OPUS编码 → 发送队列 → MQTT/WebSocket → 云端AI服务器
                                                                        ↓
                                                                   ASR 语音识别
                                                                        ↓
                                                                   LLM 大模型理解
                                                                        ↓
                                                                   TTS 语音合成
                                                                        ↓
服务器 ← MQTT/WebSocket ← 接收队列 ← OPUS解码 ← 重采样 ← I2S → 扬声器
```

#### FreeRTOS 任务 (3个)
| 任务 | 职责 |
|------|------|
| `AudioInputTask` | 从 I2S 读取麦克风数据, 送入 AFE 处理 |
| `AudioOutputTask` | 从播放队列取数据, 写入 I2S 驱动扬声器 |
| `OpusCodecTask` | OPUS 编码/解码 |

#### 队列 (4个)
| 队列 | 方向 | 内容 |
|------|------|------|
| encode_queue | 输入 → 编码 | 原始 PCM |
| decode_queue | 接收 → 解码 | OPUS 压缩包 |
| send_queue | 编码 → 协议 | OPUS 压缩包 |
| playback_queue | 解码 → 输出 | 原始 PCM |

#### OPUS 参数
- 帧长: 60ms
- 采样率: 16kHz 单声道 (编码), 24kHz (解码, 可重采样)
- VBR: 启用 (可变码率)
- DTX: 启用 (静音时不传数据)

#### AEC 回声消除 (3种模式)
| 模式 | 说明 |
|------|------|
| 关闭 | 无回声消除 |
| 设备端 | AFE 硬件加速回声消除 |
| 服务端 | 基于时间戳对齐的服务端回声消除 |

#### 音频编解码芯片 (7种驱动)
| 驱动 | 适用场景 |
|------|----------|
| `BoxAudioCodec` | ESP-BOX 系列 (ES8311 输出 + ES7210 输入) |
| `ES8311AudioCodec` | 单 ES8311 输出 |
| `ES8374AudioCodec` | ES8374 |
| `ES8388AudioCodec` | ES8388 |
| `ES8389AudioCodec` | ES8389 |
| `NoAudioCodecSimplex` | 直连 I2S, 分离的麦克风/扬声器引脚 |
| `NoAudioCodecDuplex` | 直连 I2S, 共享引脚 |
| `DummyAudioCodec` | 测试桩 |

#### 唤醒词 (3种实现)
| 实现 | 芯片 | 模型 | 说明 |
|------|------|------|------|
| `AfeWakeWord` | S3/P4 | WakeNet + AFE | 最先进, 带前端处理 |
| `CustomWakeWord` | S3/P4 | MultiNet | 自定义唤醒词 |
| `EspWakeWord` | C3/C5/C6 | WakeNet 基础版 | 无 AFE |

### 3.2 硬件抽象层 —— 如何支持 70+ 板子

#### Board 基类层次
```
Board (抽象基类)
├── WifiBoard              → 50+ WiFi 板子
├── Ml307Board             → 4G Cat.1 板子 (ML307/EC801E 芯片)
├── Nt26Board              → 4G 板子 (NT26 芯片)
└── DualNetworkBoard       → WiFi + 4G 双网络板子
```

#### 每个板子的文件结构
```
boards/<板子名>/
├── config.h          # GPIO 引脚定义
├── board.cc          # 板级实现 (初始化音频芯片/屏幕/按钮/电池)
├── config.json       # 元数据 (芯片目标, SDK 配置覆盖)
└── README.md         # (可选) 板子说明
```

#### 工厂注册机制
```cpp
// 板子实现文件底部
DECLARE_BOARD(MyBoardClass)  // 展开为 create_board() 函数
```
CMake 只编译选中的板子的 `.cc` 文件，产生唯一的 `create_board()` 实现，零虚函数开销。

#### 板子选择流程
1. 用户运行 `idf.py menuconfig`
2. 在 70+ 个选项中选板子 (按芯片过滤)
3. CMake 读取 `CONFIG_BOARD_TYPE_*` 配置
4. 只编译 `boards/<选中板子>/*.cc`

### 3.3 通信协议

#### 双协议支持
| 协议 | 信令通道 | 音频通道 | 加密 | 适用场景 |
|------|----------|----------|------|----------|
| MQTT+UDP | MQTT (TCP 1883) | UDP | AES 加密 | 低延迟, 需开放 UDP 端口 |
| WebSocket | 同一条 WS 连接 (443) | 同一条 WS 连接 | TLS | 穿透性好, 企业网络友好 |

#### 消息类型 (JSON type 字段)
| 类型 | 方向 | 用途 |
|------|------|------|
| `tts` | 下行 | TTS 流控制 (start/stop/sentence_start) |
| `stt` | 上行 | 语音识别结果回传 |
| `llm` | 下行 | AI 情感/表情更新 |
| `mcp` | 双向 | MCP 工具调用 |
| `system` | 下行 | 系统命令 (reboot) |
| `alert` | 下行 | 告警消息显示 |
| `custom` | 双向 | 自定义消息 |

#### 二进制帧格式
- BinaryProtocol2: 基础版本
- BinaryProtocol3: 增强版本 (不同头部格式)

#### MQTT 协议细节
- 心跳: 90s ping/pong
- 重连: 60s 间隔
- 按服务器返回的配置选择协议

### 3.4 MCP 服务 (设备控制)

设备端运行完整的 JSON-RPC 2.0 MCP 服务器，遵循 MCP 规范 (2024-11-05)。

#### 通用工具 (AI 可自动调用)
| 工具名称 | 功能 | 参数 |
|----------|------|------|
| `self.get_device_status` | 获取设备实时状态 | - |
| `self.audio_speaker.set_volume` | 设置音量 | 0-100 |
| `self.screen.set_brightness` | 设置屏幕亮度 | 0-100 |
| `self.screen.set_theme` | 切换主题 | "light"/"dark" |
| `self.camera.take_photo` | 拍照 + AI 理解图片 | - |

#### 用户专属工具 (仅手动触发)
| 工具名称 | 功能 | 参数 |
|----------|------|------|
| `self.get_system_info` | 芯片/闪存/内存/MAC | - |
| `self.reboot` | 系统重启 | - |
| `self.upgrade_firmware` | 从 URL OTA 升级 | firmware_url |
| `self.screen.get_info` | 显示分辨率信息 | - |
| `self.screen.snapshot` | 截屏上传为 JPEG | - |
| `self.screen.preview_image` | 显示来自 URL 的图片 | image_url |
| `self.assets.set_download_url` | 触发资源更新 | download_url |

#### 扩展性
每个板子可在初始化时注册额外的 MCP 工具 (如面包板的 `LampController` GPIO 灯控)。

### 3.5 设备状态机

```
                      Unknown
                         ↓
                      Starting
                         ↓
                   WifiConfiguring
                         │
                    ┌────┴──────┐
                    ▼           ▼
                  Idle ←──── Connecting
                    │            │
                    ▼            │
                Listening ───────┘
                    │
                    ▼
                 Speaking
                    │
                    ▼
                  Idle

其他状态:
  - Activating      → 激活码验证中
  - Upgrading       → OTA 固件升级中
  - AudioTesting    → 音频调试模式
  - FatalError      → 致命错误
```

#### 状态 → LED 颜色映射
| 状态 | LED 颜色 |
|------|----------|
| Starting | 蓝色 |
| WifiConfiguring | 黄色闪烁 |
| Idle | 白色呼吸 |
| Connecting | 蓝色闪烁 |
| Listening | 红色旋转 |
| Speaking | 绿色 |
| Upgrading | 紫色 |
| FatalError | 红色快闪 |

### 3.6 显示子系统

```
Display (抽象基类)
├── OledDisplay          → OLED 单色屏 (SSD1306/SH1106, I2C)
├── LcdDisplay           → SPI 彩色 LCD (ILI9341/ST7789/GC9A01等)
├── EmoteDisplay         → Emote 动画风格
└── LvglDisplay          → LVGL 9.5 完整框架
    ├── LvglFont         → 字体管理 (内置+图标字体)
    ├── LvglTheme        → 浅色/深色主题
    ├── LvglImage        → 图片加载
    ├── EmojiCollection  → 表情包管理
    ├── Gif              → GIF 动画解码
    └── Jpg              → JPEG 编解码
```

#### 显示元素
- **通知**: 顶部下拉通知
- **情感**: 屏幕中央表情图标 (中立/AI对话/感叹/链接等)
- **聊天**: 微信风格气泡 (用户=语音识别结果, 助手=TTS文字, 系统=状态信息)
- **状态栏**: 顶部 (电量/时间/WiFi信号)

### 3.7 网络子系统

#### 配网方式 (3种)
| 方式 | 说明 |
|------|------|
| 热点配网 | 设备开启热点, 手机连接后配置 |
| 声波配网 | 通过 AFSK 音频调制传输 WiFi 密码 |
| BLuFi | BLE 蓝牙配网 (ESP官方方案) |

#### 网络类型
| 类型 | 基类 | 说明 |
|------|------|------|
| WiFi | `WifiBoard` | 2.4GHz WiFi |
| 4G Cat.1 | `Ml307Board` | ML307/EC801E 芯片, AT 指令通过 UART |
| 4G | `Nt26Board` | NT26 芯片 |
| 双网 | `DualNetworkBoard` | WiFi + 4G 冗余备份 |

### 3.8 OTA 升级

#### 升级流程
```
1. CheckVersion()
   └─ HTTP GET → OTA 服务器
      └─ 返回: { firmware_version, firmware_url, protocol_config, activation_code? }

2. Activate() (如需激活码)
   └─ 屏幕显示激活码 + 语音播报 → 轮询激活完成

3. Upgrade()
   └─ HTTP 下载固件 (带进度回调)
      └─ 写入 OTA 分区 → 校验 → 重启

4. MarkCurrentVersionValid()
   └─ 启动成功后标记 OTA 槽位有效 (支持回滚)
```

#### 分区表 v2 (16MB Flash)
| 分区 | 大小 | 用途 |
|------|------|------|
| nvs | 16KB | 非易失性存储 |
| otadata | 8KB | OTA 元数据 |
| phy_init | 4KB | PHY 初始化数据 |
| ota_0 | 4MB | 应用固件槽 0 |
| ota_1 | 4MB | 应用固件槽 1 |
| assets | 8MB | 网络可加载资源 (唤醒词/字体/表情/主题/音效) |

---

## 四、构建系统

### 依赖组件 (idf_component.yml, ~60+)
| 类别 | 组件 |
|------|------|
| UI | LVGL 9.5, esp_lvgl_port 2.7 |
| 语音 | ESP-SR 2.3 (唤醒词), esp_audio_effects 1.2 (OPUS) |
| 音频芯片 | esp_audio_codec 2.4, esp_codec_dev 1.5 |
| 网络 | esp_ml307 3.6 (4G), esp_wifi_connect 3.1 (WiFi) |
| 字体 | xiaozhi-fonts 1.6 |
| 输入 | esp_button 4.1, knob 1.0 |
| 显示驱动 | ILI9341, GC9A01, ST77916, SH8601, ST7701, ST7796, NV3023 等 |
| 触摸驱动 | FT5x06, GT911, GT1151, CST816S, CST9217 |
| 摄像头 | esp32-camera 2.1 (S3), esp_video 1.3 (P4/S3) |
| IDF | >= 5.5.2 |

### 构建命令
```bash
source ~/esp-idf/export.sh
idf.py set-target esp32s3
cat sdkconfig.defaults.esp32s3 >> sdkconfig.defaults
idf.py build
```

---

## 五、各芯片配置对比

| 参数 | ESP32 | ESP32-C3 | ESP32-C5 | ESP32-C6 | ESP32-S3 | ESP32-P4 |
|------|-------|----------|----------|----------|----------|----------|
| Flash | 4MB | 16MB | 16MB | 16MB | 16MB | 16MB |
| PSRAM | - | - | - | - | Octal 80MHz | 200MHz |
| 唤醒词 | WN9 | WN9S_noAFE | WN9S_noAFE | WN9S_noAFE | WN9+AFE | WN9+AFE |
| CPU | 240MHz | 160MHz | 240MHz | 160MHz | 240MHz | 360MHz |
| 板子数 | ~5 | ~5 | ~2 | ~2 | ~50 | ~4 |

---

## 六、支持的语言 (40+)

```
ar-SA  bg-BG  bn-IN  cs-CZ  da-DK  de-DE  el-GR  en-GB  en-US
es-ES  fi-FI  fil-PH  fr-FR  he-IL  hi-IN  hu-HU  id-ID  it-IT
ja-JP  ko-KR  lv-LV  ms-MY  nb-NO  nl-NL  pl-PL  pt-BR  ro-RO
ru-RU  sk-SK  sr-RS  sv-SE  th-TH  tl-PH  tr-TR  uk-UA  vi-VN
zh-CN  zh-TW  zh-HK  yue-CN  mn-MN
```

每个语言包含 `language.json` (UI 字符串) + 语音 TTS `.ogg` 文件。

---

## 七、ESP32-S3 N16R8 专属配置

你的开发板对应的配置 (`sdkconfig.defaults.esp32s3`):

| 参数 | 值 |
|------|-----|
| Flash | 16MB (QIO 模式) |
| PSRAM | 8MB Octal 80MHz |
| 唤醒词 | WN9 ni hao xiao zhi + AFE |
| CPU | 240MHz |
| 分区表 | `partitions/v2/16m.csv` |
| 指令缓存 | 32KB |
| 数据缓存行 | 64B |
| LVGL 快照 | 启用 |
| USB Host | 启用 |

---

## 八、关键设计特点

1. **极致硬件灵活性**: 70+ 板子, 5 种芯片, 7 种音频编解码芯片, 3+ 显示类型
2. **OPUS 高效语音流**: 在受限网络上实现低码率高质量语音传输
3. **双协议支持**: MQTT+UDP (低延迟) / WebSocket (穿透好)
4. **设备端 MCP 服务器**: AI 可直接控制设备硬件 (音量/屏幕/相机/LED/GPIO)
5. **离线唤醒**: 本地运行唤醒词检测, 无需联网
6. **OTA 升级**: 双分区 + 回滚保护, 资源分区支持独立更新
7. **内存优化**: minimal_build 裁剪 IDF 组件, 按需编译减少 flash 占用
8. **状态机 + 观察者**: 清晰的状态转换逻辑, LED/屏幕自动响应状态变化
