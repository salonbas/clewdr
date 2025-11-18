# Clewdr Server API 測試分析報告

## 概述

執行了 `test-clewdr-server.sh` 腳本，該腳本旨在測試 Clewdr 伺服器對 Claude API 端點的兼容性，包括不同模型、參數、多輪對話、工具調用、系統提示詞和邊界情況。

**測試結果總結：**

*   **總測試數：** 26
*   **通過：** 0
*   **失敗：** 26
*   **成功率：** 0%

所有測試均未通過。

## 主要發現

### 1. Claude Web API (`/v1/chat/completions`) 請求失敗：`No cookie available` (HTTP 500)

絕大多數針對 `/v1/chat/completions` 端點的測試（包括基礎模型測試、參數組合測試、多輪對話測試、系統提示詞測試和邊界情況測試）都返回了 `HTTP 500 Internal Server Error`，錯誤訊息為 `{"error": {"message": "No cookie available", "type": "no_cookie_available", "code": 500}}`。

這表明 Clewdr 伺服器在處理這些請求時，預期存在某種 `cookie`，但測試腳本並未提供。這可能是因為 Claude Web API 的底層實現需要特定的會話 cookie 才能與 Claude 服務器進行交互。

### 2. Anthropic 格式端點 (`/v1/messages`) 認證失敗：`Key/Password Invalid` (HTTP 401)

針對 Anthropic 原生格式端點 `/v1/messages` 的測試返回了 `HTTP 401 Unauthorized`，錯誤訊息為 `{"error": {"message": "Key/Password Invalid", "type": "invalid_auth", "code": 401}}`。

儘管測試腳本在請求中包含了 `Authorization: Bearer ${API_KEY}` 頭部，但該端點仍報告認證失敗。這可能意味著：
*   `/v1/messages` 端點需要不同於 `Bearer Token` 的認證機制。
*   提供的 `API_KEY` 對於此特定端點無效。
*   該端點可能需要額外的配置或不同的認證憑證。

### 3. 工具調用測試 (`/v1/chat/completions` with `tools` parameter) 請求體反序列化失敗：`missing field name` (HTTP 422)

所有工具調用測試（測試 16、17、18）都返回了 `HTTP 422 Unprocessable Entity`，錯誤訊息類似於 `{"error": {"message": "Failed to deserialize the JSON body into the target type: tools[0]: missing field name at line X column Y", "type": "json_rejection", "code": 422}}`。

這表明測試腳本中 `tools` 參數的 JSON 結構與 Clewdr 伺服器預期的工具定義結構不匹配。錯誤訊息明確指出缺少了 `name` 字段，這可能暗示伺服器對工具定義的解析方式與測試腳本中的格式存在差異。

### 4. 流式響應格式不標準

流式響應測試未能檢測到標準的 SSE (Server-Sent Events) 格式，這很可能是因為底層請求本身就因 `No cookie available` 錯誤而失敗，導致沒有正確的流式數據返回。

## 建議

1.  **解決 `No cookie available` 錯誤：**
    *   檢查 Clewdr 伺服器的配置，了解 Claude Web API 是否需要特定的會話管理或 cookie 設置。
    *   如果需要，更新測試腳本以在請求中包含必要的 cookie。這可能需要先通過另一個端點獲取會話 cookie。
    *   或者，如果 Clewdr 伺服器旨在代理不需要 cookie 的 Claude API，則需要檢查伺服器代碼中處理 cookie 的邏輯。

2.  **解決 `/v1/messages` 認證問題：**
    *   確認 Anthropic 原生格式端點的正確認證方式。它可能需要不同的 `Authorization` 頭部格式或不同的憑證類型。
    *   檢查 Clewdr 伺服器中處理 `/v1/messages` 端點認證的邏輯。

3.  **修正工具調用 JSON 結構：**
    *   仔細比對 Clewdr 伺服器預期的工具定義 JSON 結構與測試腳本中使用的結構。根據錯誤訊息，可能需要調整 `tools` 數組中每個工具對象的字段，特別是 `name` 字段的定義。

4.  **重新運行測試：**
    *   在解決上述問題後，重新運行 `test-clewdr-server.sh` 腳本，以驗證修復是否有效。

這些問題的解決將有助於確保 Clewdr 伺服器能夠正確地代理 Claude API 請求。
