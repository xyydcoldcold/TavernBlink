import Foundation

struct AppStrings {
    let language: AppLanguage

    init(_ language: AppLanguage) {
        self.language = language
    }

    private func text(_ english: String, _ chinese: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }

    func statusMessage(_ status: AppStatus) -> String {
        switch status {
        case .needsInstall:
            return text(
                "Network component is not installed",
                "网络组件尚未安装"
            )
        case .needsApproval:
            return text(
                "Approve TavernBlink in System Settings",
                "请在系统设置中批准 TavernBlink"
            )
        case .configurationMissing:
            return text(
                "Transparent proxy is not configured",
                "透明代理尚未配置"
            )
        case .starting:
            return text(
                "Network component is starting",
                "正在启动网络组件"
            )
        case .readyNoFlow:
            return text(
                "Ready; waiting for a target flow",
                "已就绪，正在等待目标连接"
            )
        case let .readyWithFlow(count):
            return language == .simplifiedChinese
                ? "已就绪：检测到 \(count) 个目标连接"
                : "Ready with \(count) target flow\(count == 1 ? "" : "s")"
        case .disconnecting:
            return text(
                "Closing target flows",
                "正在关闭目标连接"
            )
        case let .success(count):
            return language == .simplifiedChinese
                ? "已关闭 \(count) 个目标连接"
                : "Closed \(count) target flow\(count == 1 ? "" : "s")"
        case .error:
            return text(
                "An operation failed",
                "操作失败"
            )
        }
    }

    var quitFailedTitle: String {
        text(
            "TavernBlink could not quit safely",
            "TavernBlink 无法安全退出"
        )
    }

    var proxyStillActive: String {
        text(
            "The transparent proxy is still active. TavernBlink was left open.",
            "透明代理仍在运行，因此 TavernBlink 保持开启。"
        )
    }

    var ok: String {
        text("OK", "好")
    }

    var teamID: String {
        text("Team ID", "团队 ID")
    }

    var blizzardVerificationWarning: String {
        text(
            "Blizzard code verified; bundle resources were not fully verified.",
            "暴雪代码签名已验证，但 App 资源未能完整验证。"
        )
    }

    var noVerifiedHearthstone: String {
        text(
            "No verified Hearthstone application selected.",
            "尚未选择并验证《炉石传说》App。"
        )
    }

    var phaseZeroObservations: String {
        text("Phase 0 flow observations", "第 0 阶段连接观测")
    }

    func flowSummary(observed: Int, matched: Int) -> String {
        language == .simplifiedChinese
            ? "已观测 TCP：\(observed) · 目标匹配：\(matched)"
            : "TCP observed: \(observed) · target matches: \(matched)"
    }

    func lastSigningID(_ identifier: String?) -> String {
        let value = identifier ?? text("not observed", "尚未观测")
        return language == .simplifiedChinese
            ? "最近来源签名 ID：\(value)"
            : "Last source signing ID: \(value)"
    }

    func flowsMissingSigningID(_ count: Int) -> String {
        language == .simplifiedChinese
            ? "缺少签名 ID 的连接：\(count)"
            : "Flows missing signing ID: \(count)"
    }

    var installNetworkComponent: String {
        text("Install Network Component", "安装网络组件")
    }

    var chooseHearthstone: String {
        text("Choose Hearthstone…", "选择《炉石传说》…")
    }

    var configureAndStartProxy: String {
        text("Configure and Start Proxy", "配置并启动代理")
    }

    var disconnectNow: String {
        text("Disconnect Now", "立即断线")
    }

    var refresh: String {
        text("Refresh", "刷新")
    }

    var settings: String {
        text("Settings…", "设置…")
    }

    var quitTavernBlink: String {
        text("Quit TavernBlink", "退出 TavernBlink")
    }

    var closeActiveFlowHelp: String {
        text(
            "Close the active Hearthstone target flow.",
            "关闭当前《炉石传说》目标连接。"
        )
    }

    var waitingForActiveFlowHelp: String {
        text(
            "Waiting for an active Hearthstone target flow.",
            "正在等待《炉石传说》的活动目标连接。"
        )
    }

    var settingsTitle: String {
        text("TavernBlink Settings", "TavernBlink 设置")
    }

    var general: String {
        text("General", "通用")
    }

    var languageLabel: String {
        text("Language", "语言")
    }

    var languageHint: String {
        text(
            "Changes apply immediately and are remembered after TavernBlink restarts.",
            "更改会立即生效，并在 TavernBlink 重启后保留。"
        )
    }

    var setupGuide: String {
        text("Setup guide", "设置指南")
    }

    var setupDescription: String {
        text(
            "Installation, proxy configuration, and target verification are separate so each step can be checked independently.",
            "安装、代理配置和目标验证彼此独立，方便逐步检查。"
        )
    }

    var requiredOrder: String {
        text("Required order", "操作顺序")
    }

    var installAndApprove: String {
        text(
            "Install and approve the Network System Extension.",
            "安装并批准网络系统扩展。"
        )
    }

    var chooseAndVerify: String {
        text(
            "Choose Hearthstone and verify its Blizzard signing ID and Team ID.",
            "选择《炉石传说》，并验证其暴雪签名 ID 和团队 ID。"
        )
    }

    var saveAndStart: String {
        text(
            "Save and start the transparent proxy configuration.",
            "保存并启动透明代理配置。"
        )
    }

    var restartHearthstone: String {
        text(
            "Restart Hearthstone so new flows can reach the provider.",
            "重新启动《炉石传说》，使新连接进入代理。"
        )
    }

    var important: String {
        text("Important", "重要提示")
    }

    var riskWarning: String {
        text(
            "This is an unofficial tool. Forcing a disconnect may violate Blizzard rules and may put the account at risk.",
            "这是非官方工具。强制断线可能违反暴雪规则，并可能给游戏账号带来风险。"
        )
    }

    var chooseHearthstoneTitle: String {
        text("Choose Hearthstone", "选择《炉石传说》")
    }

    var verifyApp: String {
        text("Verify App", "验证 App")
    }

    var chooseHearthstoneMessage: String {
        text(
            "Select the official Hearthstone application.",
            "请选择官方《炉石传说》App。"
        )
    }

    var chooseAndVerifyFirst: String {
        text(
            "Choose and verify Hearthstone first.",
            "请先选择并验证《炉石传说》。"
        )
    }

    var chooseAgainToReverify: String {
        text(
            "Choose Hearthstone again so TavernBlink can reverify it before starting.",
            "请重新选择《炉石传说》，以便 TavernBlink 在启动前再次验证。"
        )
    }

    func revalidationFailed(_ details: String) -> String {
        language == .simplifiedChinese
            ? "《炉石传说》重新验证失败：\(details)"
            : "Hearthstone revalidation failed: \(details)"
    }

    var restartRequired: String {
        text(
            "A restart is required to finish activating the extension.",
            "需要重新启动 Mac 才能完成扩展激活。"
        )
    }

    func errorMessage(_ error: Error) -> String {
        if let error = error as? TargetAppIdentityResolver.IdentityError {
            return identityErrorMessage(error)
        }
        if let error = error as? ProxyManagerController.ControllerError {
            return proxyControllerErrorMessage(error)
        }
        if let error = error as? ProviderMessenger.MessagingError {
            return messagingErrorMessage(error)
        }
        return error.localizedDescription
    }

    private func identityErrorMessage(
        _ error: TargetAppIdentityResolver.IdentityError
    ) -> String {
        switch error {
        case .notAnApplication:
            return text(
                "Choose a macOS application bundle.",
                "请选择一个 macOS App。"
            )
        case let .staticCode(status):
            return language == .simplifiedChinese
                ? "无法检查 App 签名（OSStatus \(status)）。"
                : "Unable to inspect the app signature (OSStatus \(status))."
        case let .requirement(status):
            return language == .simplifiedChinese
                ? "无法创建《炉石传说》签名要求（OSStatus \(status)）。"
                : "Unable to create the Hearthstone signing requirement (OSStatus \(status))."
        case let .invalidSignature(status):
            return language == .simplifiedChinese
                ? "所选 App 没有可接受的代码签名（OSStatus \(status)）。"
                : "The selected app does not have an acceptable code signature (OSStatus \(status))."
        case .missingTeamIdentifier:
            return text(
                "The selected app signature has no Team ID.",
                "所选 App 的签名没有团队 ID。"
            )
        case .missingSigningIdentifier:
            return text(
                "The selected app signature has no signing identifier.",
                "所选 App 的签名没有签名 ID。"
            )
        case let .unexpectedIdentity(signingIdentifier, teamIdentifier):
            return language == .simplifiedChinese
                ? "所选 App 不是受支持的暴雪《炉石传说》版本（签名 ID：\(signingIdentifier)，团队 ID：\(teamIdentifier)）。"
                : "The selected app is not the supported Blizzard Hearthstone build (signing ID: \(signingIdentifier), Team ID: \(teamIdentifier))."
        }
    }

    private func proxyControllerErrorMessage(
        _ error: ProxyManagerController.ControllerError
    ) -> String {
        switch error {
        case .noManager:
            return text(
                "The TavernBlink transparent proxy configuration is missing.",
                "缺少 TavernBlink 透明代理配置。"
            )
        case .invalidSession:
            return text(
                "The transparent proxy provider session is unavailable.",
                "透明代理提供程序会话不可用。"
            )
        case .startTimedOut:
            return text(
                "The transparent proxy did not reach the connected state in time.",
                "透明代理未能在规定时间内连接。"
            )
        case let .duplicateConfigurations(count):
            return language == .simplifiedChinese
                ? "发现 \(count) 个 TavernBlink 代理配置。请先移除重复配置。"
                : "Found \(count) TavernBlink proxy configurations. Remove duplicates before continuing."
        case let .activeFlowsPreventDisable(count):
            return language == .simplifiedChinese
                ? "仍有 \(count) 个目标连接处于活动状态，因此已阻止退出。TavernBlink 保持代理运行，以免中断游戏连接。请退出《炉石传说》后重试。"
                : "Quit was blocked because \(count) target flow\(count == 1 ? " is" : "s are") still active. TavernBlink left the proxy running so the game connection was not interrupted. Exit Hearthstone, then try Quit again."
        case let .disablePreflightRejected(summary):
            return language == .simplifiedChinese
                ? "TavernBlink 无法安全确认所有目标连接均已关闭，因此取消退出并保持代理启用。\(summary)"
                : "TavernBlink could not safely verify that all target flows had closed, so Quit was cancelled and the proxy was left enabled. \(summary)"
        case .providerBusy:
            return text(
                "The transparent proxy is changing state. Wait for it to settle before quitting.",
                "透明代理正在切换状态。请等待状态稳定后再退出。"
            )
        }
    }

    private func messagingErrorMessage(
        _ error: ProviderMessenger.MessagingError
    ) -> String {
        switch error {
        case let .encoding(underlyingError):
            return language == .simplifiedChinese
                ? "无法编码代理命令：\(underlyingError.localizedDescription)"
                : "Unable to encode provider command: \(underlyingError.localizedDescription)"
        case let .sending(underlyingError):
            return language == .simplifiedChinese
                ? "无法发送代理命令：\(underlyingError.localizedDescription)"
                : "Unable to send provider command: \(underlyingError.localizedDescription)"
        case .missingResponse:
            return text(
                "The provider did not return a response.",
                "代理提供程序没有返回响应。"
            )
        case let .decoding(underlyingError):
            return language == .simplifiedChinese
                ? "无法解码代理响应：\(underlyingError.localizedDescription)"
                : "Unable to decode provider response: \(underlyingError.localizedDescription)"
        }
    }
}
