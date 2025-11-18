#!/bin/bash

# Clewdr Gemini API 測試腳本
# 目的：依據 GEMINI_API_DETAILED.md 驗證 Clewdr 在 http://127.0.0.1:8484 的外部請求格式

set -uo pipefail

# -----------------------------------------------------------------------------
# 基本設定（可依需要覆蓋環境變數）
# -----------------------------------------------------------------------------
BASE_URL="${BASE_URL:-http://127.0.0.1:8484}"
API_KEY="${API_KEY:-k9rZeLu6tEHA9jQx43TkyUBTXP6NN2SuYVDtgkUxK5bTfUveCWm3BYnQPt4Br6zR}"
MODEL_ID="${GEMINI_MODEL:-models/gemini-2.5-pro-exp}"
NATIVE_GENERATE_PATH="/v1/v1beta/${MODEL_ID}:generateContent"
NATIVE_STREAM_PATH="/v1/v1beta/${MODEL_ID}:streamGenerateContent"
OAI_ENDPOINT="/gemini/chat/completions"

# -----------------------------------------------------------------------------
# 終端配色
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# 測試統計
# -----------------------------------------------------------------------------
PASSED=0
FAILED=0
TOTAL=0

# -----------------------------------------------------------------------------
# 輔助函式
# -----------------------------------------------------------------------------
print_section() {
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
}

print_test() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}測試 $TOTAL: $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

run_json_test() {
    local test_name="$1"
    local url="$2"
    local body="$3"
    local expected_status="${4:-200}"
    shift 4 2>/dev/null || true
    local curl_args=("$@")

    TOTAL=$((TOTAL + 1))
    print_test "$test_name"

    echo -e "${YELLOW}請求 URL:${NC} $url"
    echo -e "${YELLOW}請求 Body:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"

    echo -e "\n${YELLOW}響應:${NC}"
    local response
    local curl_exit_code=0
    response=$(curl -s -w "\n%{http_code}" --max-time 30 -X POST "$url" \
        -H "Content-Type: application/json" \
        "${curl_args[@]}" \
        -d "$body" 2>&1) || curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo -e "${RED}✗ curl 請求失敗 (退出碼: $curl_exit_code)${NC}"
        echo "$response"
        FAILED=$((FAILED + 1))
        return 1
    fi

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local resp_body
    resp_body=$(echo "$response" | sed '$d')

    echo "HTTP Status: $http_code"
    if [ -n "$resp_body" ]; then
        echo "$resp_body" | jq '.' 2>/dev/null || echo "$resp_body"
    else
        echo "(無響應內容)"
    fi

    if [ "$http_code" = "$expected_status" ]; then
        echo -e "\n${GREEN}✓ 測試通過${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "\n${RED}✗ 測試失敗 (期望: $expected_status, 實際: $http_code)${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

run_stream_test() {
    local test_name="$1"
    local url="$2"
    local body="$3"
    local expected_pattern="${4:-data:}"
    shift 4 2>/dev/null || true
    local curl_args=("$@")

    TOTAL=$((TOTAL + 1))
    print_test "$test_name"

    echo -e "${YELLOW}請求 URL:${NC} $url"
    echo -e "${YELLOW}請求 Body:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"

    echo -e "\n${YELLOW}響應 (前 500 字符):${NC}"
    local response
    local curl_exit_code=0
    response=$(curl -s -N --max-time 15 -X POST "$url" \
        -H "Content-Type: application/json" \
        "${curl_args[@]}" \
        -d "$body" 2>&1) || curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo -e "${RED}✗ curl 請求失敗 (退出碼: $curl_exit_code)${NC}"
        echo "$response"
        FAILED=$((FAILED + 1))
        return 1
    fi

    if [ -z "$response" ]; then
        echo "(無響應內容)"
        echo -e "\n${RED}✗ 流式響應為空${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi

    echo "$response" | head -c 500
    echo -e "\n..."

    if echo "$response" | grep -q "$expected_pattern"; then
        echo -e "\n${GREEN}✓ 流式響應包含 '$expected_pattern'${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "\n${RED}✗ 流式響應缺少 '$expected_pattern'${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 服務器連接檢查
# -----------------------------------------------------------------------------
echo -e "${BLUE}檢查服務器連接: ${BASE_URL}${NC}"
if ! curl -s --max-time 5 "${BASE_URL}" > /dev/null 2>&1; then
    echo -e "${RED}警告: 無法連接到服務器 ${BASE_URL}${NC}"
    echo -e "${YELLOW}請確認 Clewdr 服務器正在運行${NC}\n"
else
    echo -e "${GREEN}✓ 服務器連接正常${NC}\n"
fi

# -----------------------------------------------------------------------------
# 1. AI Studio 原生 API 測試（Gemini 原生格式）
# -----------------------------------------------------------------------------
print_section "1. AI Studio 原生 API 測試"

# 1.1 查詢參數帶 key 的基本請求
run_json_test "原生 API - Query Key 基礎請求" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}?key=${API_KEY}" \
    '{
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": "請用一句話介紹 Clewdr 是什麼。"}
                ]
            }
        ]
    }'

# 1.2 Header 認證 + systemInstruction + generationConfig
run_json_test "原生 API - Header Key + systemInstruction" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}" \
    '{
        "systemInstruction": {
            "parts": [{"text": "You are a precise technical assistant."}]
        },
        "generationConfig": {
            "temperature": 0.2,
            "topK": 32,
            "topP": 0.9,
            "maxOutputTokens": 256,
            "stopSequences": ["END"]
        },
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": "列出撰寫 shell script 的三個最佳實踐。"}
                ]
            }
        ]
    }' \
    200 \
    -H "x-goog-api-key: ${API_KEY}"

# 1.3 多模態請求 (text + inlineData)
run_json_test "原生 API - 多模態 inlineData" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}?key=${API_KEY}" \
    '{
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": "請描述下面圖片的顏色調性。"},
                    {
                        "inlineData": {
                            "mimeType": "image/png",
                            "data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAGgwJ/l1IanwAAAABJRU5ErkJggg=="
                        }
                    }
                ]
            }
        ]
    }'

# 1.4 tools + functionCall + functionResponse + codeExecution
run_json_test "原生 API - 工具定義與函數回傳" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}?key=${API_KEY}" \
    '{
        "tools": [
            {
                "functionDeclarations": [
                    {
                        "name": "get_weather",
                        "description": "Return weather by city",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "location": {"type": "string", "description": "City name"}
                            },
                            "required": ["location"]
                        }
                    }
                ]
            },
            {"codeExecution": {}}
        ],
        "contents": [
            {
                "role": "user",
                "parts": [{"text": "幫我查詢東京天氣並計算 21*2。"}]
            },
            {
                "role": "model",
                "parts": [
                    {
                        "functionCall": {
                            "id": "call-123",
                            "name": "get_weather",
                            "args": {"location": "Tokyo"}
                        }
                    },
                    {
                        "codeExecution": {
                            "language": "PYTHON",
                            "code": "print(21*2)"
                        }
                    }
                ]
            },
            {
                "role": "user",
                "parts": [
                    {
                        "functionResponse": {
                            "id": "call-123",
                            "name": "get_weather",
                            "response": {"temperature": "25C", "condition": "sunny"}
                        }
                    },
                    {
                        "codeExecutionResult": {
                            "outcome": "OUTCOME_OK",
                            "output": "42"
                        }
                    }
                ]
            }
        ]
    }'

# 1.5 多輪對話 (含 model role)
run_json_test "原生 API - 多輪對話" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}?key=${API_KEY}" \
    '{
        "contents": [
            {
                "role": "user",
                "parts": [{"text": "我叫 Alice。"}]
            },
            {
                "role": "model",
                "parts": [{"text": "你好 Alice！"}]
            },
            {
                "role": "user",
                "parts": [{"text": "請記住我的名字並回答 2+3=?。"}]
            }
        ]
    }'

# 1.6 流式 SSE 測試
run_stream_test "原生 API - SSE 流式" \
    "${BASE_URL}${NATIVE_STREAM_PATH}?key=${API_KEY}&alt=sse" \
    '{
        "contents": [
            {
                "role": "user",
                "parts": [{"text": "請從 1 數到 5，每行一個數字。"}]
            }
        ]
    }'

# 1.7 邊界條件：maxOutputTokens=1
run_json_test "原生 API - 最小 maxOutputTokens" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}?key=${API_KEY}" \
    '{
        "generationConfig": {"maxOutputTokens": 1},
        "contents": [
            {
                "role": "user",
                "parts": [{"text": "說 HI"}]
            }
        ]
    }'

# 1.8 錯誤處理：缺少 contents
run_json_test "原生 API - 錯誤請求 (缺少 contents)" \
    "${BASE_URL}${NATIVE_GENERATE_PATH}?key=${API_KEY}" \
    '{}' \
    400

# -----------------------------------------------------------------------------
# 2. OpenAI 相容 API 測試 (/gemini/chat/completions)
# -----------------------------------------------------------------------------
print_section "2. Gemini OpenAI 相容 API 測試"

# 通用 Bearer Header
AUTH_HEADER="Authorization: Bearer ${API_KEY}"

# 2.1 基礎非流式請求
run_json_test "OpenAI 格式 - 基礎請求" \
    "${BASE_URL}${OAI_ENDPOINT}" \
    '{
        "model": "gemini-2.5-pro-exp",
        "messages": [
            {"role": "user", "content": "請簡要介紹 Gemini API 測試目標。"}
        ],
        "max_tokens": 256,
        "temperature": 0.5
    }' \
    200 \
    -H "$AUTH_HEADER"

# 2.2 流式請求 (stream: true)
run_stream_test "OpenAI 格式 - 流式 SSE" \
    "${BASE_URL}${OAI_ENDPOINT}" \
    '{
        "model": "gemini-2.5-pro-exp",
        "messages": [
            {"role": "user", "content": "列出 3 種測試策略。"}
        ],
        "stream": true,
        "max_tokens": 128
    }' \
    "data:" \
    -H "$AUTH_HEADER"

# 2.3 工具呼叫
run_json_test "OpenAI 格式 - 工具調用" \
    "${BASE_URL}${OAI_ENDPOINT}" \
    '{
        "model": "gemini-2.5-pro-exp",
        "messages": [
            {"role": "user", "content": "查詢巴黎天氣並計算 5+7。"}
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Returns weather for a location",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "location": {"type": "string"}
                        },
                        "required": ["location"]
                    }
                }
            }
        ],
        "tool_choice": "auto",
        "max_tokens": 200
    }' \
    200 \
    -H "$AUTH_HEADER"

# 2.4 邊界條件：超大 max_tokens
run_json_test "OpenAI 格式 - 大 max_tokens" \
    "${BASE_URL}${OAI_ENDPOINT}" \
    '{
        "model": "gemini-2.5-pro-exp",
        "messages": [
            {"role": "user", "content": "寫一段約 200 字的測試報告摘要。"}
        ],
        "max_tokens": 4096
    }' \
    200 \
    -H "$AUTH_HEADER"

# 2.5 錯誤測試：缺少 model
run_json_test "OpenAI 格式 - 錯誤請求 (缺少 model)" \
    "${BASE_URL}${OAI_ENDPOINT}" \
    '{
        "messages": [
            {"role": "user", "content": "這個請求應該要失敗。"}
        ]
    }' \
    400 \
    -H "$AUTH_HEADER"

# -----------------------------------------------------------------------------
# 測試總結
# -----------------------------------------------------------------------------
print_section "測試總結"
echo -e "總測試數: ${TOTAL}"
echo -e "${GREEN}通過: ${PASSED}${NC}"
echo -e "${RED}失敗: ${FAILED}${NC}"
SUCCESS_RATE=0
if [ "$TOTAL" -gt 0 ]; then
    SUCCESS_RATE=$(( PASSED * 100 / TOTAL ))
fi
echo -e "成功率: ${SUCCESS_RATE}%"

# -----------------------------------------------------------------------------
# 生成 JSON 測試報告
# -----------------------------------------------------------------------------
REPORT_FILE="gemini-clewdr-test-report-$(date +%Y%m%d-%H%M%S).json"
cat > "$REPORT_FILE" <<EOF
{
  "test_summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "success_rate": $SUCCESS_RATE,
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "server_info": {
    "base_url": "$BASE_URL",
    "native_path": "$NATIVE_GENERATE_PATH",
    "oai_endpoint": "$OAI_ENDPOINT"
  },
  "model": "$MODEL_ID"
}
EOF

echo -e "${BLUE}測試報告已輸出至: ${REPORT_FILE}${NC}\n"

