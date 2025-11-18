# Gemini API 詳細 HTTP 請求格式文檔

本文檔詳細說明 Clewdr 專案中 Gemini API 的兩個 AI Studio 端點的完整 HTTP 請求格式。

---

## 一、AI Studio 原生 API (Gemini 格式)

### 1.1 接收端點

**路由定義：**
```71:72:src/router.rs
.route("/v1/v1beta/{*path}", post(api_post_gemini))
.route("/v1/vertex/v1beta/{*path}", post(api_post_gemini))
```

**完整 URL 格式：**
```
POST http://{host}:{port}/v1/v1beta/{path}
```

**路徑變數說明：**
- `{host}`: 服務器主機地址（默認：127.0.0.1）
- `{port}`: 服務器端口（默認：8484）
- `{path}`: Gemini API 路徑，例如：
  - `models/gemini-2.0-flash-exp:generateContent`
  - `models/gemini-2.0-flash-exp:streamGenerateContent`

### 1.2 HTTP 請求格式

#### **請求方法**
```
POST
```

#### **請求頭 (Headers)**

**必需頭部：**
```
Content-Type: application/json
```

**認證方式（二選一）：**

**方式 1：查詢參數認證（推薦）**
```
無需額外 Header
```

**方式 2：Header 認證**
```
x-goog-api-key: {your-api-key}
```

**可選頭部：**
```
Accept: application/json
Accept-Encoding: gzip, deflate, br
```

#### **查詢參數 (Query Parameters)**

**認證方式 1 - 查詢參數（必需）：**
```
?key={your-api-key}&alt={alt-format}
```

**參數說明：**
- `key` (必需): 您的 Gemini API Key，通過 Clewdr 配置的用戶認證密鑰
  - 如果使用 Header 認證方式，此參數可省略
- `alt` (可選): 響應格式選項
  - `sse`: Server-Sent Events 格式（用於流式響應）

**認證方式 2 - Header（當查詢參數無 key 時）：**
- 必須提供 `x-goog-api-key` Header
- 查詢參數可包含 `alt`

#### **請求體 (Request Body)**

**Content-Type:** `application/json`

**請求體結構：**
```json
{
  "systemInstruction": {
    "parts": [
      {
        "text": "You are a helpful assistant."
      }
    ]
  },
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "function_name",
          "description": "Function description",
          "parameters": {
            "type": "object",
            "properties": {
              "param1": {
                "type": "string",
                "description": "Parameter description"
              }
            },
            "required": ["param1"]
          }
        }
      ]
    },
    {
      "googleSearch": {}
    },
    {
      "codeExecution": {}
    }
  ],
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Hello, how are you?"
        },
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "base64-encoded-image-data"
          }
        },
        {
          "executableCode": {
            "language": "PYTHON",
            "code": "print('Hello')"
          }
        },
        {
          "fileData": {
            "mimeType": "application/pdf",
            "fileUrl": "gs://bucket/file.pdf"
          }
        }
      ]
    },
    {
      "role": "model",
      "parts": [
        {
          "text": "I'm doing well, thank you!"
        },
        {
          "functionCall": {
            "id": "call_id_123",
            "name": "function_name",
            "args": {
              "param1": "value1"
            }
          }
        },
        {
          "codeExecutionResult": {
            "outcome": "OUTCOME_OK",
            "output": "Hello"
          }
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "topK": 40,
    "topP": 0.95,
    "maxOutputTokens": 8192,
    "candidateCount": 1,
    "stopSequences": ["STOP"],
    "responseMimeType": "text/plain",
    "responseSchema": {
      "type": "object",
      "properties": {
        "answer": {
          "type": "string"
        }
      }
    }
  },
  "safetySettings": [
    {
      "category": "HARM_CATEGORY_HARASSMENT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_HATE_SPEECH",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_CIVIC_INTEGRITY",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    }
  ]
}
```

**注意：** Clewdr 會自動將所有 `safetySettings` 設置為 `OFF`，無需在請求中提供。

**請求體字段詳解：**

| 字段 | 類型 | 必需 | 說明 |
|------|------|------|------|
| `systemInstruction` | Object | 否 | 系統指令，用於設置模型行為 |
| `systemInstruction.parts` | Array | 是 | 指令部分數組，通常包含文本 |
| `tools` | Array | 否 | 工具定義數組，可包含函數調用、Google 搜索、代碼執行等 |
| `tools[].functionDeclarations` | Array | 否 | 函數聲明數組 |
| `tools[].googleSearch` | Object | 否 | Google 搜索工具（空對象即可啟用） |
| `tools[].codeExecution` | Object | 否 | 代碼執行工具（空對象即可啟用） |
| `contents` | Array | **是** | 對話內容數組 |
| `contents[].role` | String | 是 | 角色：`user` 或 `model` |
| `contents[].parts` | Array | 是 | 消息部分數組 |
| `contents[].parts[].text` | String | 否 | 純文本內容 |
| `contents[].parts[].inlineData` | Object | 否 | 內嵌數據（圖片等） |
| `contents[].parts[].inlineData.mimeType` | String | 是 | MIME 類型，如 `image/jpeg` |
| `contents[].parts[].inlineData.data` | String | 是 | Base64 編碼的數據 |
| `contents[].parts[].executableCode` | Object | 否 | 可執行代碼 |
| `contents[].parts[].executableCode.language` | String | 是 | 編程語言：`PYTHON` |
| `contents[].parts[].executableCode.code` | String | 是 | 代碼內容 |
| `contents[].parts[].fileData` | Object | 否 | 文件數據 |
| `contents[].parts[].fileData.mimeType` | String | 否 | MIME 類型 |
| `contents[].parts[].fileData.fileUrl` | String | 是 | 文件 URL（GS:// 或 HTTP(S)） |
| `contents[].parts[].functionCall` | Object | 否 | 函數調用（來自模型的回應） |
| `contents[].parts[].functionCall.id` | String | 否 | 調用 ID |
| `contents[].parts[].functionCall.name` | String | 是 | 函數名稱 |
| `contents[].parts[].functionCall.args` | Object | 否 | 函數參數 |
| `contents[].parts[].functionResponse` | Object | 否 | 函數響應（提供給模型的函數執行結果） |
| `contents[].parts[].functionResponse.id` | String | 否 | 對應的調用 ID |
| `contents[].parts[].functionResponse.name` | String | 是 | 函數名稱 |
| `contents[].parts[].functionResponse.response` | Object | 是 | 函數執行結果 |
| `contents[].parts[].codeExecutionResult` | Object | 否 | 代碼執行結果 |
| `contents[].parts[].codeExecutionResult.outcome` | String | 是 | 結果：`OUTCOME_OK`, `OUTCOME_FAILED`, `OUTCOME_DEADLINE_EXCEEDED` |
| `contents[].parts[].codeExecutionResult.output` | String | 否 | 輸出內容 |
| `generationConfig` | Object | 否 | 生成配置 |
| `generationConfig.temperature` | Number | 否 | 溫度參數（0.0-2.0） |
| `generationConfig.topK` | Number | 否 | Top-K 採樣 |
| `generationConfig.topP` | Number | 否 | Top-P 採樣 |
| `generationConfig.maxOutputTokens` | Number | 否 | 最大輸出 token 數 |
| `generationConfig.candidateCount` | Number | 否 | 候選數量 |
| `generationConfig.stopSequences` | Array | 否 | 停止序列 |
| `generationConfig.responseMimeType` | String | 否 | 響應 MIME 類型 |
| `generationConfig.responseSchema` | Object | 否 | JSON Schema 結構化輸出 |
| `safetySettings` | Array | 否 | 安全設置（Clewdr 會自動設置為 OFF） |

#### **完整請求範例**

**範例 1：簡單文本對話（查詢參數認證）**
```http
POST /v1/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_API_KEY HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Content-Length: 123

{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Hello, how are you?"
        }
      ]
    }
  ]
}
```

**範例 2：流式響應（Header 認證）**
```http
POST /v1/v1beta/models/gemini-2.0-flash-exp:streamGenerateContent?alt=sse HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
x-goog-api-key: YOUR_API_KEY
Content-Length: 123

{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Tell me a story"
        }
      ]
    }
  ]
}
```

**範例 3：帶工具和圖片的多模態請求**
```http
POST /v1/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_API_KEY HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Content-Length: 456

{
  "systemInstruction": {
    "parts": [
      {
        "text": "You are a helpful assistant that can analyze images and call functions."
      }
    ]
  },
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "get_weather",
          "description": "Get weather information for a location",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {
                "type": "string",
                "description": "The city name"
              }
            },
            "required": ["location"]
          }
        }
      ]
    }
  ],
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "What's in this image?"
        },
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "/9j/4AAQSkZJRgABAQAAAQ..."
          }
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 2048
  }
}
```

### 1.3 認證處理

**認證中間件：**
```32:48:src/middleware/auth.rs
pub struct RequireQueryKeyAuth;
impl<S> FromRequestParts<S> for RequireQueryKeyAuth
where
    S: Sync,
{
    type Rejection = ClewdrError;
    async fn from_request_parts(
        parts: &mut axum::http::request::Parts,
        _: &S,
    ) -> Result<Self, Self::Rejection> {
        let query = GeminiArgs::from_request_parts(parts, &()).await?;
        if !CLEWDR_CONFIG.load().user_auth(&query.key) {
            warn!("Invalid query key: {}", query.key);
            return Err(ClewdrError::InvalidAuth);
        }
        Ok(Self)
    }
}
```

**認證邏輯：**
1. 首先嘗試從查詢參數 `key` 獲取 API Key
2. 如果查詢參數無 `key`，則從 Header `x-goog-api-key` 獲取
3. 驗證 Key 是否在 Clewdr 配置的用戶認證列表中
4. 驗證通過後，請求才會被處理

### 1.4 響應格式

**成功響應（非流式）：**
```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 456

{
  "candidates": [
    {
      "content": {
        "role": "model",
        "parts": [
          {
            "text": "Hello! I'm doing well, thank you for asking. How can I help you today?"
          }
        ]
      },
      "finishReason": "STOP",
      "safetyRatings": [],
      "citationMetadata": {}
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 10,
    "candidatesTokenCount": 25,
    "totalTokenCount": 35
  },
  "modelVersion": "gemini-2.0-flash-exp"
}
```

**流式響應（SSE 格式）：**
```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Transfer-Encoding: chunked

data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Hello"}]}}]}

data: {"candidates":[{"content":{"parts":[{"text":"!"}]}}]}

data: {"candidates":[{"content":{"parts":[{"text":" How"}]}}]}

data: {"candidates":[{"content":{"parts":[{"text":" can"}]}}]}

data: [DONE]
```

**錯誤響應：**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": {
    "code": 400,
    "message": "Model not found in path or vertex config",
    "status": "INVALID_ARGUMENT"
  }
}
```

### 1.5 後端轉發請求格式

**Clewdr 接收請求後，會轉發到 Google Gemini API：**

**目標端點：**
```
POST https://generativelanguage.googleapis.com/v1beta/{path}?key={actual-gemini-key}&alt={alt}
```

**轉發請求頭：**
```
Content-Type: application/json
```

**轉發請求體：**
- 與接收到的請求體相同（但會自動關閉安全設置）

**轉發代碼：**
```217:229:src/gemini_state/mod.rs
GeminiApiFormat::Gemini => {
    let mut query_vec = self.query.to_vec();
    query_vec.push(("key", key.as_str()));
    self.client
        .post(format!("{}v1beta/{}", GEMINI_ENDPOINT, self.path))
        .query(&query_vec)
        .json(&p)
        .send()
        .await
        .context(WreqSnafu {
            msg: "Failed to send request to Gemini API",
        })?
}
```

**說明：**
- `GEMINI_ENDPOINT` = `https://generativelanguage.googleapis.com/`
- Clewdr 會從配置的 Gemini Keys 池中選擇一個可用的 Key
- 會將查詢參數（如 `alt`）一併轉發
- 會在查詢參數中添加實際的 Gemini API Key

---

## 二、AI Studio OpenAI 相容 API

### 2.1 接收端點

**路由定義：**
```77:78:src/router.rs
.route("/gemini/chat/completions", post(api_post_gemini_oai))
.route("/gemini/vertex/chat/completions", post(api_post_gemini_oai))
```

**完整 URL 格式：**
```
POST http://{host}:{port}/gemini/chat/completions
```

### 2.2 HTTP 請求格式

#### **請求方法**
```
POST
```

#### **請求頭 (Headers)**

**必需頭部：**
```
Content-Type: application/json
Authorization: Bearer {your-api-key}
```

**可選頭部：**
```
Accept: application/json
Accept-Encoding: gzip, deflate, br
```

**認證方式：**
- **必須使用 Bearer Token 認證**
- Token 通過 `Authorization` Header 提供
- Token 必須在 Clewdr 配置的用戶認證列表中

#### **查詢參數 (Query Parameters)**
```
無查詢參數
```

#### **請求體 (Request Body)**

**Content-Type:** `application/json`

**請求體結構（OpenAI 格式）：**
```json
{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant."
    },
    {
      "role": "user",
      "content": "Hello, how are you?"
    },
    {
      "role": "assistant",
      "content": "I'm doing well, thank you!"
    },
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What's in this image?"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
          }
        }
      ]
    }
  ],
  "stream": false,
  "temperature": 0.7,
  "top_p": 0.95,
  "top_k": 40,
  "max_tokens": 2048,
  "stop": ["STOP", "\n\n"],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather information for a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {
              "type": "string",
              "description": "The city name"
            }
          },
          "required": ["location"]
        }
      }
    }
  ],
  "tool_choice": "auto",
  "logit_bias": {},
  "frequency_penalty": 0.0,
  "presence_penalty": 0.0,
  "response_format": {
    "type": "json_object",
    "schema": {
      "type": "object",
      "properties": {
        "answer": {
          "type": "string"
        }
      }
    }
  },
  "extra_body": {
    "google": {
      "safety_settings": [
        {
          "category": "HARM_CATEGORY_HARASSMENT",
          "threshold": "OFF"
        }
      ]
    }
  },
  "n": 1
}
```

**請求體字段詳解：**

| 字段 | 類型 | 必需 | 說明 |
|------|------|------|------|
| `model` | String | **是** | 模型名稱，例如：`gemini-2.0-flash-exp`, `gemini-pro` |
| `messages` | Array | **是** | 消息數組，按時間順序排列 |
| `messages[].role` | String | 是 | 角色：`system`, `user`, `assistant`, `tool` |
| `messages[].content` | String/Array | 是 | 消息內容（字符串或內容塊數組） |
| `messages[].content[].type` | String | 是 | 內容類型：`text`, `image_url` |
| `messages[].content[].text` | String | 否 | 文本內容（type 為 `text` 時） |
| `messages[].content[].image_url` | Object | 否 | 圖片 URL（type 為 `image_url` 時） |
| `messages[].content[].image_url.url` | String | 是 | 圖片 URL，支持 `data:` URL 或 HTTP(S) URL |
| `messages[].name` | String | 否 | 工具調用名稱（role 為 `tool` 時） |
| `messages[].tool_calls` | Array | 否 | 工具調用列表（assistant 角色） |
| `messages[].tool_calls[].id` | String | 是 | 工具調用 ID |
| `messages[].tool_calls[].type` | String | 是 | 固定為 `function` |
| `messages[].tool_calls[].function.name` | String | 是 | 函數名稱 |
| `messages[].tool_calls[].function.arguments` | String | 是 | JSON 字符串格式的函數參數 |
| `stream` | Boolean | 否 | 是否使用流式響應，默認 `false` |
| `temperature` | Number | 否 | 溫度參數（0.0-2.0），控制隨機性 |
| `top_p` | Number | 否 | Nucleus 採樣參數（0.0-1.0） |
| `top_k` | Number | 否 | Top-K 採樣參數 |
| `max_tokens` | Number | 否 | 最大生成 token 數 |
| `max_completion_tokens` | Number | 否 | 最大完成 token 數（與 max_tokens 相同） |
| `stop` | Array/String | 否 | 停止序列（字符串或字符串數組） |
| `tools` | Array | 否 | 工具定義數組（OpenAI 格式） |
| `tools[].type` | String | 是 | 工具類型，固定為 `function` |
| `tools[].function.name` | String | 是 | 函數名稱 |
| `tools[].function.description` | String | 是 | 函數描述 |
| `tools[].function.parameters` | Object | 是 | JSON Schema 格式的參數定義 |
| `tool_choice` | String/Object | 否 | 工具選擇策略：`auto`, `none`, `required` 或函數對象 |
| `logit_bias` | Object | 否 | Logit 偏置映射 |
| `frequency_penalty` | Number | 否 | 頻率懲罰（-2.0 到 2.0），**Gemini 不支持，會被忽略** |
| `presence_penalty` | Number | 否 | 存在懲罰（-2.0 到 2.0），**Gemini 不支持，會被忽略** |
| `response_format` | Object | 否 | 響應格式配置 |
| `response_format.type` | String | 否 | 格式類型：`text`, `json_object` |
| `response_format.schema` | Object | 否 | JSON Schema（當 type 為 json_object 時） |
| `extra_body` | Object | 否 | 額外的 Gemini 特定參數 |
| `extra_body.google.safety_settings` | Array | 否 | 安全設置（Clewdr 會自動設置為 OFF） |
| `n` | Number | 否 | 生成候選數量，默認 1 |

#### **完整請求範例**

**範例 1：簡單文本對話**
```http
POST /gemini/chat/completions HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
Content-Length: 234

{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "user",
      "content": "Hello, how are you?"
    }
  ],
  "stream": false,
  "temperature": 0.7
}
```

**範例 2：流式響應**
```http
POST /gemini/chat/completions HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
Content-Length: 234

{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "user",
      "content": "Tell me a story about space"
    }
  ],
  "stream": true,
  "temperature": 0.8,
  "max_tokens": 1000
}
```

**範例 3：多模態請求（圖片）**
```http
POST /gemini/chat/completions HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
Content-Length: 456

{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What's in this image?"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ..."
          }
        }
      ]
    }
  ],
  "temperature": 0.7
}
```

**範例 4：帶工具調用的請求**
```http
POST /gemini/chat/completions HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
Content-Length: 678

{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant that can check the weather."
    },
    {
      "role": "user",
      "content": "What's the weather in Tokyo?"
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather information for a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {
              "type": "string",
              "description": "The city and state, e.g. San Francisco, CA"
            },
            "unit": {
              "type": "string",
              "enum": ["celsius", "fahrenheit"],
              "description": "Temperature unit"
            }
          },
          "required": ["location"]
        }
      }
    }
  ],
  "tool_choice": "auto",
  "temperature": 0.7
}
```

**範例 5：工具響應（繼續對話）**
```http
POST /gemini/chat/completions HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
Content-Length: 890

{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "user",
      "content": "What's the weather in Tokyo?"
    },
    {
      "role": "assistant",
      "content": null,
      "tool_calls": [
        {
          "id": "call_abc123",
          "type": "function",
          "function": {
            "name": "get_weather",
            "arguments": "{\"location\": \"Tokyo\"}"
          }
        }
      ]
    },
    {
      "role": "tool",
      "name": "get_weather",
      "content": "{\"temperature\": 22, \"condition\": \"Sunny\", \"humidity\": 65}"
    }
  ],
  "temperature": 0.7
}
```

**範例 6：結構化輸出（JSON 模式）**
```http
POST /gemini/chat/completions HTTP/1.1
Host: 127.0.0.1:8484
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
Content-Length: 567

{
  "model": "gemini-2.0-flash-exp",
  "messages": [
    {
      "role": "user",
      "content": "Extract the key information from: 'John Doe, age 30, lives in New York'"
    }
  ],
  "response_format": {
    "type": "json_object",
    "schema": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "age": {
          "type": "number"
        },
        "location": {
          "type": "string"
        }
      },
      "required": ["name", "age", "location"]
    }
  }
}
```

### 2.3 認證處理

**認證中間件：**
```104:123:src/middleware/auth.rs
pub struct RequireBearerAuth;
impl<S> FromRequestParts<S> for RequireBearerAuth
where
    S: Sync,
{
    type Rejection = ClewdrError;
    async fn from_request_parts(
        parts: &mut axum::http::request::Parts,
        _: &S,
    ) -> Result<Self, Self::Rejection> {
        let AuthBearer(key) = AuthBearer::from_request_parts(parts, &())
            .await
            .map_err(|_| ClewdrError::InvalidAuth)?;
        if !CLEWDR_CONFIG.load().user_auth(&key) {
            warn!("Invalid Bearer key: {}", key);
            return Err(ClewdrError::InvalidAuth);
        }
        Ok(Self)
    }
}
```

**認證邏輯：**
1. 從 `Authorization` Header 提取 Bearer Token
2. 驗證 Token 是否在 Clewdr 配置的用戶認證列表中
3. 驗證通過後，請求才會被處理

### 2.4 響應格式

**成功響應（非流式）：**
```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 456

{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "gemini-2.0-flash-exp",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! I'm doing well, thank you for asking. How can I help you today?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 25,
    "total_tokens": 35
  }
}
```

**流式響應（Server-Sent Events）：**
```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Transfer-Encoding: chunked

data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1677652288,"model":"gemini-2.0-flash-exp","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1677652288,"model":"gemini-2.0-flash-exp","choices":[{"index":0,"delta":{"content":"!"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1677652288,"model":"gemini-2.0-flash-exp","choices":[{"index":0,"delta":{"content":" How"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1677652288,"model":"gemini-2.0-flash-exp","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

**帶工具調用的響應：**
```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 567

{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "gemini-2.0-flash-exp",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": null,
        "tool_calls": [
          {
            "id": "call_abc123",
            "type": "function",
            "function": {
              "name": "get_weather",
              "arguments": "{\"location\": \"Tokyo\"}"
            }
          }
        ]
      },
      "finish_reason": "tool_calls"
    }
  ],
  "usage": {
    "prompt_tokens": 20,
    "completion_tokens": 15,
    "total_tokens": 35
  }
}
```

**錯誤響應：**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": {
    "message": "Invalid request: model parameter is required",
    "type": "invalid_request_error",
    "param": "model",
    "code": "missing_parameter"
  }
}
```

### 2.5 後端轉發請求格式

**Clewdr 接收請求後，會將 OpenAI 格式轉換為 Gemini 格式並轉發：**

**目標端點：**
```
POST https://generativelanguage.googleapis.com/v1beta/openai/chat/completions
```

**轉發請求頭：**
```
Content-Type: application/json
Authorization: Bearer {actual-gemini-key}
```

**轉發請求體：**
- Clewdr 會將 OpenAI 格式的請求體轉換為 Gemini API 能理解的格式
- 自動添加安全設置（設置為 OFF）
- 處理工具定義轉換

**轉發代碼：**
```230:239:src/gemini_state/mod.rs
GeminiApiFormat::OpenAI => self
    .client
    .post(format!("{GEMINI_ENDPOINT}v1beta/openai/chat/completions",))
    .header(AUTHORIZATION, format!("Bearer {key}"))
    .json(&p)
    .send()
    .await
    .context(WreqSnafu {
        msg: "Failed to send request to Gemini OpenAI API",
    })?,
```

**說明：**
- Clewdr 會從配置的 Gemini Keys 池中選擇一個可用的 Key
- 使用 Bearer Token 認證方式
- 請求體會自動進行格式轉換

---

## 三、通用注意事項

### 3.1 認證要求

1. **AI Studio 原生 API**：
   - 支持查詢參數 `key` 或 Header `x-goog-api-key`
   - Key 必須在 Clewdr 配置的 `user_auth` 列表中

2. **AI Studio OpenAI 相容 API**：
   - 必須使用 Bearer Token 認證
   - Token 必須在 Clewdr 配置的 `user_auth` 列表中

### 3.2 安全設置

Clewdr 會自動將所有安全設置關閉，無需在請求中提供 `safetySettings` 或 `extra_body.google.safety_settings`。

**原生 API：**
```136:148:src/types/gemini/request.rs
impl GeminiRequestBody {
    pub fn safety_off(&mut self) {
        self.safety_settings = Some(json!([
          { "category": "HARM_CATEGORY_HARASSMENT", "threshold": "OFF" },
          { "category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "OFF" },
          { "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "OFF" },
          { "category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "OFF" },
          {
            "category": "HARM_CATEGORY_CIVIC_INTEGRITY",
            "threshold": "OFF"
          }
        ]));
    }
}
```

### 3.3 流式響應

1. **原生 API**：使用查詢參數 `alt=sse` 啟用 SSE 流式響應
2. **OpenAI 相容 API**：使用請求體中的 `stream: true` 啟用流式響應

### 3.4 錯誤處理

所有錯誤都會返回適當的 HTTP 狀態碼和錯誤信息：

- `400 Bad Request`：請求格式錯誤或參數無效
- `401 Unauthorized`：認證失敗
- `403 Forbidden`：API Key 無權限
- `429 Too Many Requests`：請求過於頻繁
- `500 Internal Server Error`：服務器內部錯誤

### 3.5 請求大小限制

- 最大請求體大小取決於服務器配置（默認通常為 10MB）
- Gemini API 本身有 token 限制，請參考 Google 文檔

### 3.6 代理支持

Clewdr 支持通過配置設置 HTTP 代理，所有轉發請求都會通過代理發送（如果配置了代理）。

---

## 四、代碼引用

### 4.1 路由定義
```69:85:src/router.rs
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

### 4.2 請求處理
```12:33:src/api/gemini.rs
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

```35:56:src/api/gemini.rs
pub async fn api_post_gemini_oai(
    State(providers): State<GeminiProviders>,
    GeminiOaiPreprocess(body, ctx): GeminiOaiPreprocess,
) -> Result<Response, ClewdrError> {
    if ctx.vertex {
        providers
            .vertex()
            .invoke(GeminiInvocation {
                payload: GeminiPayload::OpenAI(body),
                context: ctx,
            })
            .await
    } else {
        providers
            .ai_studio()
            .invoke(GeminiInvocation {
                payload: GeminiPayload::OpenAI(body),
                context: ctx,
            })
            .await
    }
}
```

---

## 五、總結

本文檔詳細說明了 Clewdr 專案中 Gemini API 的兩個 AI Studio 端點的完整 HTTP 請求格式，包括：

1. **AI Studio 原生 API**：使用 Gemini 原生格式，支持查詢參數或 Header 認證
2. **AI Studio OpenAI 相容 API**：使用 OpenAI 格式，必須使用 Bearer Token 認證

兩個端點都支持流式和非流式響應，並提供完整的錯誤處理和認證機制。

