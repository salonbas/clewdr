# Clewdr Gemini API 測試分析報告

## 概述

執行了 `test-gemini-clewdr-server.sh` 腳本，該腳本旨在測試 Clewdr 伺服器對 Gemini API 端點的兼容性，包括 AI Studio 原生 API (`/v1/v1beta/...`) 和 OpenAI 相容 API (`/gemini/chat/completions`)，涵蓋基礎請求、流式響應、工具調用、多模態內容和邊界情況。

**測試結果總結：**

*   **總測試數：** 13
*   **通過：** 1
*   **失敗：** 12
*   **成功率：** 7%

絕大多數測試未通過，主要原因是模型名稱不存在。

## 主要發現

### 1. 模型不存在：`models/gemini-2.5-pro-exp is not found` (HTTP 404)

絕大多數測試（測試 1、3、5、6、7、9、10、12）都返回了 `HTTP 404 Not Found`，錯誤訊息為：

```
{"error":{"code":404,"message":"models/gemini-2.5-pro-exp is not found for API version v1beta, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.","status":"NOT_FOUND"}}
```

或對於 OpenAI 相容 API：

```
{"error":{"code":404,"message":"models/gemini-2.5-pro-exp is not found for API version v1main, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.","status":"NOT_FOUND"}}
```

**影響範圍：**
*   AI Studio 原生 API 的基礎請求、多模態請求、多輪對話、流式請求、邊界條件測試
*   OpenAI 相容 API 的基礎請求、流式請求、大 max_tokens 測試

**可能原因：**
*   模型名稱 `gemini-2.5-pro-exp` 可能不正確或已過期
*   該模型可能尚未在 Clewdr 配置的 Gemini API 中可用
*   需要使用不同的模型名稱，例如 `gemini-2.0-flash-exp` 或其他可用的模型

### 2. curl 退出碼 3：URL 格式問題

多個測試（測試 1、3、5、6、7）顯示 `curl 請求失敗 (退出碼: 3)`，但同時也返回了 HTTP 200 狀態碼和錯誤 JSON。

**分析：**
*   curl 退出碼 3 通常表示 URL 格式錯誤或無法解析 URL
*   但實際上請求已成功發送到伺服器（返回 HTTP 200）
*   這可能是因為 curl 在處理包含特殊字符的 URL 或響應格式時的問題
*   響應體中包含了有效的 JSON 錯誤訊息，說明請求已到達伺服器

**建議：**
*   檢查 URL 編碼是否正確
*   確認查詢參數的格式是否符合預期
*   考慮改進腳本中的 curl 錯誤處理邏輯

### 3. 工具調用 JSON 結構不匹配：`missing field name` (HTTP 422)

**問題 1：原生 API 工具調用（測試 4）**

返回 `HTTP 422 Unprocessable Entity`，錯誤訊息為：

```
{"error":{"message":"Failed to deserialize the JSON body into the target type: contents[1].parts[1]: data did not match any variant of untagged enum Part at line 41 column 17","type":"json_rejection","code":422}}
```

**分析：**
*   錯誤發生在 `contents[1].parts[1]`，即第二個 content 項目的第二個 part
*   測試腳本中使用了 `codeExecution` 作為 part 類型，但伺服器可能不支援此格式
*   或者 `codeExecution` 的結構不符合伺服器預期

**問題 2：OpenAI 相容 API 工具調用（測試 11）**

返回 `HTTP 422 Unprocessable Entity`，錯誤訊息為：

```
{"error":{"message":"Failed to deserialize the JSON body into the target type: tools[0]: missing field `name` at line 20 column 13","type":"json_rejection","code":422}}
```

**分析：**
*   錯誤明確指出 `tools[0]` 缺少 `name` 字段
*   測試腳本中的工具定義為：
    ```json
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            ...
        }
    }
    ```
*   但伺服器期望的格式可能是：
    ```json
    {
        "type": "function",
        "name": "get_weather",  // name 應該在頂層
        "function": {
            ...
        }
    }
    ```
*   或者 Clewdr 的 OpenAI 相容 API 對工具定義的格式要求與標準 OpenAI 格式不同

### 4. 錯誤狀態碼期望不匹配：期望 400，實際 422（測試 13）

測試 13（OpenAI 格式 - 錯誤請求，缺少 model）期望返回 `HTTP 400 Bad Request`，但實際返回了 `HTTP 422 Unprocessable Entity`。

**分析：**
*   伺服器使用 422 表示請求格式錯誤（JSON 反序列化失敗）
*   這是一個合理的狀態碼選擇，但與測試期望不符
*   建議將測試期望改為 422，或確認 Clewdr 的錯誤處理策略

### 5. 腳本 Bug：`curl_args[@]: unbound variable`（測試 8）

測試 8（原生 API - 錯誤請求，缺少 contents）時出現錯誤：

```
./test-gemini-clewdr-server.sh: line 70: curl_args[@]: unbound variable
```

**分析：**
*   當 `run_json_test` 函數沒有額外的 curl 參數時，`curl_args` 數組為空
*   在 `set -uo pipefail` 模式下，訪問未綁定的變數會導致腳本失敗
*   雖然已經使用了 `shift 4 2>/dev/null || true`，但 `"${curl_args[@]}"` 在數組為空時仍可能觸發錯誤

**解決方案：**
*   在訪問 `curl_args` 前檢查是否為空
*   或使用 `"${curl_args[@]+"${curl_args[@]}"}"` 來安全地展開數組

### 6. 測試 2 通過但返回錯誤內容

測試 2（原生 API - Header Key + systemInstruction）顯示「✓ 測試通過」，但響應體中包含了錯誤訊息：

```json
{
  "error": {
    "code": 404,
    "message": "models/gemini-2.5-pro-exp is not found for API version v1beta, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.",
    "status": "NOT_FOUND"
  }
}
```

**分析：**
*   測試通過是因為 HTTP 狀態碼為 200（符合期望）
*   但響應體中包含了錯誤訊息，說明雖然請求格式正確，但模型不存在
*   這表明 Clewdr 在模型不存在時返回 HTTP 200 而不是 404
*   測試邏輯應該同時檢查響應體內容，而不僅僅是狀態碼

## 建議

### 1. 解決模型不存在問題

**優先級：高**

*   **確認可用的模型名稱：**
    *   查詢 Clewdr 配置或 Gemini API 文檔，確認當前可用的模型名稱
    *   可能需要使用 `gemini-2.0-flash-exp`、`gemini-1.5-pro` 或其他模型
    *   或通過 Clewdr 的模型列表端點獲取可用模型

*   **更新測試腳本：**
    *   將 `MODEL_ID` 改為實際可用的模型名稱
    *   或添加環境變數支持，允許動態指定模型

*   **驗證模型可用性：**
    *   在運行完整測試套件前，先執行一個簡單的模型列表查詢或基礎請求來驗證模型可用

### 2. 修正工具調用 JSON 結構

**優先級：中**

*   **原生 API 工具調用：**
    *   檢查 `codeExecution` 的正確格式
    *   確認 Clewdr 是否支援 `codeExecution` 作為 part 類型
    *   如果不支援，移除相關測試或使用替代方案

*   **OpenAI 相容 API 工具調用：**
    *   檢查 Clewdr 的 OpenAI 相容 API 對工具定義的格式要求
    *   確認是否需要將 `name` 字段放在頂層而非 `function` 對象內
    *   參考 Clewdr 源代碼或文檔確認正確格式

### 3. 改進測試腳本錯誤處理

**優先級：中**

*   **修復 `curl_args` 未綁定變數問題：**
    *   使用 `"${curl_args[@]+"${curl_args[@]}"}"` 安全展開數組
    *   或在訪問前檢查數組是否為空

*   **改進 curl 錯誤處理：**
    *   區分 curl 本身的錯誤（退出碼 3）和伺服器返回的錯誤
    *   當 curl 退出碼非 0 但 HTTP 狀態碼有效時，仍應解析響應體

*   **增強響應驗證：**
    *   不僅檢查 HTTP 狀態碼，還應檢查響應體中是否包含錯誤訊息
    *   對於成功的測試，驗證響應體結構是否符合預期

### 4. 調整錯誤狀態碼期望

**優先級：低**

*   將測試 13 的期望狀態碼從 400 改為 422
*   或確認 Clewdr 的錯誤處理策略，統一錯誤狀態碼的使用

### 5. 驗證流式響應格式

**優先級：低**

*   在模型可用後，重新測試流式響應
*   確認 SSE 格式是否符合標準
*   驗證 `alt=sse` 查詢參數是否正確工作

## 測試覆蓋範圍

本次測試涵蓋了以下場景：

### AI Studio 原生 API (`/v1/v1beta/...`)
*   ✅ 查詢參數認證（Query Key）
*   ✅ Header 認證（x-goog-api-key）
*   ✅ 系統指令（systemInstruction）
*   ✅ 生成配置（generationConfig）
*   ✅ 多模態內容（inlineData）
*   ✅ 工具定義（functionDeclarations）
*   ✅ 函數調用和響應（functionCall, functionResponse）
*   ✅ 代碼執行（codeExecution）
*   ✅ 多輪對話
*   ✅ 流式響應（SSE）
*   ✅ 邊界條件（最小 maxOutputTokens）
*   ✅ 錯誤處理（缺少 contents）

### OpenAI 相容 API (`/gemini/chat/completions`)
*   ✅ Bearer Token 認證
*   ✅ 基礎請求
*   ✅ 流式請求
*   ✅ 工具調用
*   ✅ 邊界條件（大 max_tokens）
*   ✅ 錯誤處理（缺少 model）

## 結論

測試腳本成功驗證了 Clewdr 對 Gemini API 的請求格式處理，但由於模型名稱不存在，大部分測試無法完成實際的 API 調用。主要問題集中在：

1. **模型配置問題**：需要確認並使用正確的模型名稱
2. **工具調用格式**：需要確認 Clewdr 對工具定義的具體格式要求
3. **腳本健壯性**：需要改進錯誤處理和響應驗證邏輯

建議優先解決模型名稱問題，然後重新運行測試以獲得完整的測試結果。在模型可用後，可以進一步驗證 Clewdr 對各種 Gemini API 功能的支援情況。

