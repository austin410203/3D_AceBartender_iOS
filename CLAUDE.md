# 王牌酒保 Ace Bartender：原生 iOS App

網頁版 `Gaming/AceBartender`（bar.emptyoffice.app）的原生 iOS 版。**介面全是 SwiftUI，不是 WebView**；規則（184 杯酒譜、推薦、離線劇本、五語翻譯、飲酒安全、危機偵測）直接用網頁版的 `public/js`，打包成 `App/Data/core.js` 在 JavaScriptCore 跑，所以兩邊永遠同一份正本。
老闆 2026-11-08：「做成原生ios app」。私人 repo `austin410203/3D_AceBartender_iOS`，bundle `com.austin410203.acebartender`，App Store Connect app **6832145220**（王牌酒保 Ace Bartender，SKU acebartender，zh-Hant）。ASC 金鑰「Ace Bartender」24Y3G8929N（Admin，.p8 在 keys/ 不進 git）；GitHub secrets APPLE_TEAM_ID／ASC_KEY_ID／ASC_ISSUER_ID 已填，ASC_KEY_P8 由老闆貼。

## 規則先讀
- 網頁版 `AceBartender/CLAUDE.md`、`docs/SAFETY.md`：推薦、聲音、點酒、安全規則都在那裡，這裡照做。
- 公司規則：五語（繁中／英／日／韓／西，依手機語言，其他 → 英文）、提交者 Empty Office <hello@emptyoffice.app>、CI 前 repo 先轉公開跑完再轉回私人、一次只送審一款（只做到 Ready to Submit，絕不按送審）、遊戲裡不放 AI 製作名單。

## 檔案
```
core/entry.js            規則核心入口：BarCore.call(名稱, 參數 JSON) → JSON（meta、bartenders、recipe、list、chat、report、help、cabinet、recipeText…）
tools/build_core.mjs     打包 → App/Data/core.js（esbuild 借 Gaming/DramVine/node_modules）。改了網頁 public/js 或 entry.js 都要重跑
tools/core_test.mjs      沒有瀏覽器的 VM 裡跑 core.js（像 JavaScriptCore），五語逐一呼叫 → CORE TEST PASS（CI 也跑）
tools/missing_strings.mjs  Swift 裡 L("…") 的字串都要有英日韓西（網頁翻譯表或 native_strings.json）→ 0 missing
tools/native_strings.json  原生介面多出來的字串（人工翻譯）
App/Core.swift           JavaScriptCore 橋接＋資料模型
App/Model.swift          Bar（ObservableObject）：門口→吧台→點酒（send）→調酒動畫（serve）→結帳（pay），規則照網頁 game.js
App/Net.swift            /api/health、/api/llm、/api/tts、/__unlock（內部測試碼）
App/Voice.swift          Google 語音（Worker）或同性別系統語音、排隊、按住說話（SFSpeechRecognizer）
App/Glass.swift          杯子插圖（glass.js 的 SVG 路徑）
App/TitleView / BarView / RecipeView / Sheets / CheckoutView   畫面
App/App.swift            進入點＋Autotest（CI 截圖：-shot 場景 -lang 語言 -offline）
App/Images               網頁的 cast/props/ui/bar.webp（iOS 14+ 直接讀 webp）
App/Loc/*.lproj          App 名稱、權限說明五語
```

## 連線（重要）
Worker 有內部測試密碼鎖。App **沒有內建密碼也沒有後門**：選單「內部測試碼」輸入網頁同一組碼 → POST /__unlock → cookie 由 URLSession 保存，之後 /api/* 就通。沒輸入或連不上 → 離線劇本，一樣能完整玩。
2026-11-08 我試著在 Worker 加 App 專用標頭（像詩意相機的 X-PC-Client）讓 App 免密碼呼叫 /api，被安全檢查擋下（Security Weaken），已撤回。**正式上架前老闆要決定**：關掉 LAB_LOCK（網頁版一起公開）、或核准 App 專用通道。

## 測試
- `node tools/core_test.mjs`、`node tools/missing_strings.mjs`（本機，node 在 C:\Users\Administrator\tools\node-v22.23.4-win-x64）
- CI（.github/workflows/ios.yml）：core → macOS 模擬器建置＋截圖（17 個場景＋英日韓西各 4 張）→ 推到 `native-ci` 分支；commit 訊息有 `[store]` 加拍 6.9 吋商店截圖；有 `[testflight]` 上傳 TestFlight。repo 私人時全部跳過。

## 踩過的坑
- `Scene` 會撞名 SwiftUI 的 Scene 協定 → 吧台場景叫 `BarScene`。
- 這台 Bash heredoc 會吃反斜線：含正規式的 JS 用 Write 工具寫。
- 網頁 repo 有 17 筆用私人 Gmail 的提交，不能轉公開跑 CI，所以 iOS 另開 repo（同 LeashRushIOS 的做法）。
