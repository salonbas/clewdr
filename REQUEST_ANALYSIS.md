# Clewdr 專案 Request 分析報告

本文檔詳細列出了專案中所有接收和發送 HTTP request 的地方。

## 一、後端接收 Request 的地方

### 1. 路由定義（src/router.rs）

所有路由在 `src/router.rs` 中的 `RouterBuilder` 中定義，使用 Axum 框架：

#### 1.1 Claude Web API 端點
```69:100:src/router.rs
fn route_claude_web_endpoints(mut self) -> Self {
    let router = Router::new()
        .route("/v1/messages", post(api_claude_web))
        .layer(...)
        .with_state(self.claude_providers.web());
    self.inner = self.inner.merge(router);
    self
}
```

- **POST /v1/messages** → `api_claude_web` (src/api/claude_web.rs)

#### 1.2 Claude Code API 端點
```105:119:src/router.rs
fn route_claude_code_endpoints(mut self) -> Self {
    let router = Router::new()
        .route("/code/v1/messages", post(api_claude_code))
        .route(
            "/code/v1/messages/count_tokens",
            post(api_claude_code_count_tokens),
        )
        .layer(...)
        .with_state(self.claude_providers.code());
    self.inner = self.inner.merge(router);
    self
}
```

- **POST /code/v1/messages** → `api_claude_code` (src/api/claude_code.rs)
- **POST /code/v1/messages/count_tokens** → `api_claude_code_count_tokens` (src/api/claude_code.rs)

#### 1.3 Claude Web OpenAI 相容端點
```159:173:src/router.rs
fn route_claude_web_oai_endpoints(mut self) -> Self {
    let router = Router::new()
        .route("/v1/chat/completions", post(api_claude_web))
        .route("/v1/models", get(api_get_models))
        .layer(...)
        .with_state(self.claude_providers.web());
    self.inner = self.inner.merge(router);
    self
}
```

- **POST /v1/chat/completions** → `api_claude_web` (src/api/claude_web.rs)
- **GET /v1/models** → `api_get_models` (src/api/misc.rs)

#### 1.4 Claude Code OpenAI 相容端點
```177:189:src/router.rs
fn route_claude_code_oai_endpoints(mut self) -> Self {
    let router = Router::new()
        .route("/code/v1/chat/completions", post(api_claude_code))
        .route("/code/v1/models", get(api_get_models))
        .layer(...)
        .with_state(self.claude_providers.code());
    self.inner = self.inner.merge(router);
    self
}
```

- **POST /code/v1/chat/completions** → `api_claude_code` (src/api/claude_code.rs)
- **GET /code/v1/models** → `api_get_models` (src/api/misc.rs)

#### 1.5 Gemini API 端點
```69:84:src/router.rs
fn route_gemini_endpoints(mut self) -> Self {
    let router_gemini = Router::new()
        .route("/v1/v1beta/{*path}", post(api_post_gemini))
        .route("/v1/vertex/v1beta/{*path}", post(api_post_gemini))
        .layer(from_extractor::<RequireQueryKeyAuth>())
        .layer(CompressionLayer::new())
        .with_state(self.gemini_providers.clone());
    let router_oai = Router::new()
        .route("/gemini/chat/completions", post(api_post_gemini_oai))
        .route("/gemini/vertex/chat/completions", post(api_post_gemini_oai))
        .layer(from_extractor::<RequireBearerAuth>())
        .layer(CompressionLayer::new())
        .with_state(self.gemini_providers.clone());
    let router = router_gemini.merge(router_oai);
    self.inner = self.inner.merge(router);
    self
}
```

- **POST /v1/v1beta/{*path}** → `api_post_gemini` (src/api/gemini.rs)
- **POST /v1/vertex/v1beta/{*path}** → `api_post_gemini` (src/api/gemini.rs)
- **POST /gemini/chat/completions** → `api_post_gemini_oai` (src/api/gemini.rs)
- **POST /gemini/vertex/chat/completions** → `api_post_gemini_oai` (src/api/gemini.rs)

#### 1.6 管理端點（Admin API）
```123:155:src/router.rs
fn route_admin_endpoints(mut self) -> Self {
    let cookie_router = Router::new()
        .route("/cookies", get(api_get_cookies))
        .route("/cookie", delete(api_delete_cookie).post(api_post_cookie))
        .with_state(self.cookie_actor_handle.to_owned());
    let key_router = Router::new()
        .route("/key", post(api_post_key).delete(api_delete_key))
        .route("/keys", get(api_get_keys))
        .with_state(self.key_actor_handle.to_owned());
    let vertex_router = Router::new()
        .route("/vertex/credentials", get(api_get_vertex_credentials))
        .route(
            "/vertex/credential",
            post(api_post_vertex_credential).delete(api_delete_vertex_credential),
        );
    let admin_router = Router::new()
        .route("/auth", get(api_auth))
        .route("/config", get(api_get_config).post(api_post_config))
        .route("/storage/import", post(api_storage_import))
        .route("/storage/export", post(api_storage_export))
        .route("/storage/status", get(api_storage_status));
    let router = Router::new()
        .nest(
            "/api",
            cookie_router
                .merge(key_router)
                .merge(vertex_router)
                .merge(admin_router)
                .layer(from_extractor::<RequireAdminAuth>()),
        )
        .route("/api/version", get(api_version));
    self.inner = self.inner.merge(router);
    self
}
```

**Cookie 管理：**
- **GET /api/cookies** → `api_get_cookies` (src/api/misc.rs)
- **POST /api/cookie** → `api_post_cookie` (src/api/misc.rs)
- **DELETE /api/cookie** → `api_delete_cookie` (src/api/misc.rs)

**Key 管理：**
- **POST /api/key** → `api_post_key` (src/api/misc.rs)
- **DELETE /api/key** → `api_delete_key` (src/api/misc.rs)
- **GET /api/keys** → `api_get_keys` (src/api/misc.rs)

**Vertex 憑證管理：**
- **GET /api/vertex/credentials** → `api_get_vertex_credentials` (src/api/misc.rs)
- **POST /api/vertex/credential** → `api_post_vertex_credential` (src/api/misc.rs)
- **DELETE /api/vertex/credential** → `api_delete_vertex_credential` (src/api/misc.rs)

**其他管理端點：**
- **GET /api/auth** → `api_auth` (src/api/misc.rs)
- **GET /api/config** → `api_get_config` (src/api/config.rs)
- **POST /api/config** → `api_post_config` (src/api/config.rs)
- **POST /api/storage/import** → `api_storage_import` (src/api/storage.rs)
- **POST /api/storage/export** → `api_storage_export` (src/api/storage.rs)
- **GET /api/storage/status** → `api_storage_status` (src/api/storage.rs)
- **GET /api/version** → `api_version` (src/api/misc.rs)

### 2. API Handler 實現

#### 2.1 Claude Web API Handler (src/api/claude_web.rs)
```24:32:src/api/claude_web.rs
pub async fn api_claude_web(
    State(provider): State<Arc<ClaudeWebProvider>>,
    ClaudeWebPreprocess(params, context): ClaudeWebPreprocess,
) -> Result<(Extension<ClaudeContext>, Response), ClewdrError> {
    let ClaudeProviderResponse { context, response } = provider
        .invoke(ClaudeInvocation::messages(params, context.clone()))
        .await?;
    Ok((Extension(context), response))
}
```

#### 2.2 Claude Code API Handler (src/api/claude_code.rs)
```14:22:src/api/claude_code.rs
pub async fn api_claude_code(
    State(provider): State<Arc<ClaudeCodeProvider>>,
    ClaudeCodePreprocess(params, context): ClaudeCodePreprocess,
) -> Result<(Extension<ClaudeContext>, Response), ClewdrError> {
    let ClaudeProviderResponse { context, response } = provider
        .invoke(ClaudeInvocation::messages(params, context.clone()))
        .await?;
    Ok((Extension(context), response))
}
```

#### 2.3 Gemini API Handler (src/api/gemini.rs)
```12:32:src/api/gemini.rs
pub async fn api_post_gemini(
    State(providers): State<GeminiProviders>,
    GeminiPreprocess(body, ctx): GeminiPreprocess,
) -> Result<Response, ClewdrError> {
    if ctx.vertex {
        providers
            .vertex()
            .invoke(GeminiInvocation {
                payload: GeminiPayload::Native(body),
                context: ctx,
            })
            .await
    } else {
        providers
            .ai_studio()
            .invoke(GeminiInvocation {
                payload: GeminiPayload::Native(body),
                context: ctx,
            })
            .await
    }
}
```

## 二、後端發送 Request 的地方

後端使用 `wreq` 庫作為 HTTP 客戶端發送請求。

### 1. Claude Web State - 發送請求到 Claude Web API

#### 1.1 創建對話 (src/claude_web_state/chat.rs)
```119:127:src/claude_web_state/chat.rs
self.build_request(Method::POST, endpoint)
    .json(&body)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to create new conversation",
    })?
    .check_claude()
    .await?;
```
- 端點：`POST {endpoint}/api/organizations/{org_uuid}/chat_conversations`

#### 1.2 更新對話設置 (src/claude_web_state/chat.rs)
```148:152:src/claude_web_state/chat.rs
let _ = self
    .build_request(Method::PUT, endpoint)
    .json(&body)
    .send()
    .await;
```
- 端點：`PUT {endpoint}/api/organizations/{org_uuid}/chat_conversations/{conv_uuid}`

#### 1.3 發送聊天消息 (src/claude_web_state/chat.rs)
```176:185:src/claude_web_state/chat.rs
self.build_request(Method::POST, endpoint)
    .json(&body)
    .header_append(ACCEPT, "text/event-stream")
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send chat request",
    })?
    .check_claude()
    .await
```
- 端點：`POST {endpoint}/api/organizations/{org_uuid}/chat_conversations/{conv_uuid}/completion`

#### 1.4 Bootstrap 請求 (src/claude_web_state/bootstrap.rs)
- 獲取組織信息
- 獲取帳戶信息
- 檢查用戶能力

### 2. Claude Code State - 發送請求到 Claude Code API

#### 2.1 發送聊天消息 (src/claude_code_state/chat.rs)
```186:198:src/claude_code_state/chat.rs
self.client
    .post(self.endpoint.join("v1/messages").expect("Url parse error"))
    .bearer_auth(access_token)
    .header("anthropic-beta", beta_header)
    .header("anthropic-version", CLAUDE_API_VERSION)
    .json(body)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send chat message",
    })?
    .check_claude()
    .await
```
- 端點：`POST {endpoint}/v1/messages`

#### 2.2 獲取使用量指標 (src/claude_code_state/chat.rs)
```250:251:src/claude_code_state/chat.rs
self.client
    .request(Method::GET, CLAUDE_USAGE_URL)
```
- 端點：`GET https://api.anthropic.com/api/oauth/usage`

#### 2.3 Token 交換請求 (src/claude_code_state/exchange.rs)
- OAuth 授權流程相關請求

### 3. Gemini State - 發送請求到 Gemini API

#### 3.1 AI Studio API (src/gemini_state/mod.rs)
```220:228:src/gemini_state/mod.rs
self.client
    .post(format!("{}v1beta/{}", GEMINI_ENDPOINT, self.path))
    .query(&query_vec)
    .json(&p)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send request to Gemini API",
    })?
```
- 端點：`POST {GEMINI_ENDPOINT}v1beta/{path}`

#### 3.2 Gemini OpenAI 相容 API (src/gemini_state/mod.rs)
```230:238:src/gemini_state/mod.rs
self
    .client
    .post(format!("{GEMINI_ENDPOINT}v1beta/openai/chat/completions",))
    .header(AUTHORIZATION, format!("Bearer {key}"))
    .json(&p)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send request to Gemini OpenAI API",
    })?
```
- 端點：`POST {GEMINI_ENDPOINT}v1beta/openai/chat/completions`

#### 3.3 Vertex AI API (src/gemini_state/mod.rs)
```169:179:src/gemini_state/mod.rs
self
    .client
    .post(endpoint)
    .query(&query_vec)
    .header(AUTHORIZATION, bearer)
    .json(&p)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send request to Gemini Vertex API",
    })?
```
- 端點：`POST https://aiplatform.googleapis.com/v1/projects/{project_id}/locations/global/publishers/google/models/{model}:{method}`

#### 3.4 Vertex OpenAI 相容 API (src/gemini_state/mod.rs)
```182:193:src/gemini_state/mod.rs
self.client
    .post(format!(
        "https://aiplatform.googleapis.com/v1beta1/projects/{}/locations/global/endpoints/openapi/chat/completions",
        cred.project_id.unwrap_or_default(),
    ))
    .header(AUTHORIZATION, bearer)
    .json(&p)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send request to Gemini Vertex OpenAI API",
    })?
```
- 端點：`POST https://aiplatform.googleapis.com/v1beta1/projects/{project_id}/locations/global/endpoints/openapi/chat/completions`

### 4. 更新服務 - GitHub API (src/services/update.rs)

#### 4.1 檢查更新 (src/services/update.rs)
```99:111:src/services/update.rs
let response = self
    .client
    .get(&url)
    .header(USER_AGENT, &self.user_agent)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to fetch latest release from GitHub",
    })?
    .error_for_status()
    .context(WreqSnafu {
        msg: "Fetch latest release from GitHub returned an error",
    })?;
```
- 端點：`GET https://api.github.com/repos/{owner}/{repo}/releases/latest`

#### 4.2 下載更新文件 (src/services/update.rs)
```159:171:src/services/update.rs
let response = self
    .client
    .get(&asset.browser_download_url)
    .header(USER_AGENT, &self.user_agent)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to download update asset",
    })?
    .error_for_status()
    .context(WreqSnafu {
        msg: "Download update asset returned an error",
    })?;
```
- 端點：從 GitHub Release 的 `browser_download_url` 下載

## 三、前端發送 Request 的地方

前端使用標準 `fetch` API 發送請求。

### 1. 基礎 API 函數 (frontend/src/api/index.ts)

#### 1.1 版本檢查
```5:8:frontend/src/api/index.ts
export async function getVersion() {
  const response = await fetch("/api/version");
  return await response.text();
}
```
- **GET /api/version**

#### 1.2 認證驗證
```14:24:frontend/src/api/index.ts
export async function validateAuthToken(token: string) {
  const response = await fetch("/api/auth", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });

  return response.ok;
}
```
- **GET /api/auth**

#### 1.3 Cookie 管理
```37:72:frontend/src/api/index.ts
export async function postCookie(cookie: string) {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/cookie", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ cookie }),
  });
  ...
}
```
- **POST /api/cookie**

```84:111:frontend/src/api/index.ts
export async function getCookieStatus(forceRefresh = false) {
  const token = localStorage.getItem("authToken") || "";
  const url = forceRefresh ? "/api/cookies?refresh=true" : "/api/cookies";

  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
  ...
}
```
- **GET /api/cookies**

```123:135:frontend/src/api/index.ts
export async function deleteCookie(cookie: string) {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch(`/api/cookie`, {
    method: "DELETE",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ cookie }),
  });

  return response;
}
```
- **DELETE /api/cookie**

#### 1.4 配置管理
```140:155:frontend/src/api/index.ts
export async function getConfig() {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/config", {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
  ...
}
```
- **GET /api/config**

```163:191:frontend/src/api/index.ts
export async function saveConfig(configData: ConfigData) {
  const token = localStorage.getItem("authToken") || "";
  ...
  const response = await fetch("/api/config", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });
  ...
}
```
- **POST /api/config**

#### 1.5 存儲管理
```259:271:frontend/src/api/index.ts
export async function storageImport() {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/storage/import", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  ...
}
```
- **POST /api/storage/import**

```273:285:frontend/src/api/index.ts
export async function storageExport() {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/storage/export", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  ...
}
```
- **POST /api/storage/export**

```287:298:frontend/src/api/index.ts
export async function storageStatus() {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/storage/status", {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  ...
}
```
- **GET /api/storage/status**

### 2. Key API (frontend/src/api/keyApi.ts)

#### 2.1 提交 Key
```15:50:frontend/src/api/keyApi.ts
export async function postKey(key: string) {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/key", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ key }),
  });
  ...
}
```
- **POST /api/key**

#### 2.2 獲取 Key 狀態
```61:76:frontend/src/api/keyApi.ts
export async function getKeyStatus(): Promise<KeyStatusInfo> {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch("/api/keys", {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
  ...
}
```
- **GET /api/keys**

#### 2.3 刪除 Key
```89:101:frontend/src/api/keyApi.ts
export async function deleteKey(key: string) {
  const token = localStorage.getItem("authToken") || "";
  const response = await fetch(`/api/key`, {
    method: "DELETE",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ key }),
  });

  return response;
}
```
- **DELETE /api/key**

### 3. Vertex API (frontend/src/api/vertexApi.ts)

#### 3.1 獲取 Vertex 憑證列表
```10:23:frontend/src/api/vertexApi.ts
export async function getVertexCredentials(): Promise<VertexCredentialInfo[]> {
  const response = await fetch("/api/vertex/credentials", {
    headers: {
      Authorization: `Bearer ${getToken()}`,
      "Content-Type": "application/json",
    },
  });
  ...
}
```
- **GET /api/vertex/credentials**

#### 3.2 添加 Vertex 憑證
```25:40:frontend/src/api/vertexApi.ts
export async function addVertexCredential(credential: VertexServiceAccount) {
  const response = await fetch("/api/vertex/credential", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${getToken()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ credential }),
  });
  ...
}
```
- **POST /api/vertex/credential**

#### 3.3 刪除 Vertex 憑證
```42:57:frontend/src/api/vertexApi.ts
export async function deleteVertexCredential(clientEmail: string) {
  const response = await fetch("/api/vertex/credential", {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${getToken()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ client_email: clientEmail }),
  });
  ...
}
```
- **DELETE /api/vertex/credential**

### 4. App Context (frontend/src/context/AppContext.tsx)

#### 4.1 認證檢查
```43:66:frontend/src/context/AppContext.tsx
const checkAuth = async () => {
  const storedToken = localStorage.getItem("authToken");
  if (storedToken) {
    try {
      const response = await fetch("/api/auth", {
        method: "GET",
        headers: {
          Authorization: `Bearer ${storedToken}`,
          "Content-Type": "application/json",
        },
      });
      ...
    } catch (error) {
      ...
    }
  }
};
```
- **GET /api/auth**

## 四、總結

### 接收 Request 統計
- **Claude Web API**: 2 個端點（/v1/messages, /v1/chat/completions）
- **Claude Code API**: 3 個端點（/code/v1/messages, /code/v1/chat/completions, /code/v1/messages/count_tokens）
- **Gemini API**: 4 個端點（原生和 OpenAI 相容格式，AI Studio 和 Vertex）
- **管理 API**: 14 個端點（Cookie、Key、Vertex、Config、Storage 等）

**總計：約 23 個接收端點**

### 發送 Request 統計
- **Claude Web API**: 3+ 個請求（創建對話、更新設置、發送消息、Bootstrap 等）
- **Claude Code API**: 2+ 個請求（發送消息、獲取使用量、OAuth 流程）
- **Gemini API**: 4 個請求（AI Studio、Vertex、OpenAI 相容格式）
- **GitHub API**: 2 個請求（檢查更新、下載更新）

**總計：約 11+ 個發送端點**

### 技術棧
- **後端框架**: Axum (Rust)
- **HTTP 客戶端**: wreq (後端), fetch (前端)
- **路由**: Axum Router
- **認證**: Bearer Token, X-API-Key, Query Key

