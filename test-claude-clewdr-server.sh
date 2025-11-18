#!/bin/bash

# Clewdr Server API 測試腳本
# 測試所有 Claude 模型和模式的兼容性

# 配置
BASE_URL="http://127.0.0.1:8484"
API_KEY="k9rZeLu6tEHA9jQx43TkyUBTXP6NN2SuYVDtgkUxK5bTfUveCWm3BYnQPt4Br6zR"
ENDPOINT="/v1/chat/completions"

# 顏色輸出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 測試計數器
PASSED=0
FAILED=0
TOTAL=0

# 打印測試標題
print_test() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}測試 $TOTAL: $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 執行測試
run_test() {
    local test_name="$1"
    local request_body="$2"
    local expected_status="${3:-200}"
    
    TOTAL=$((TOTAL + 1))
    print_test "$test_name"
    
    echo -e "${YELLOW}請求:${NC}"
    echo "$request_body" | jq '.' 2>/dev/null || echo "$request_body"
    
    echo -e "\n${YELLOW}響應:${NC}"
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "${BASE_URL}${ENDPOINT}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "$request_body")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    echo "HTTP Status: $http_code"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    
    if [ "$http_code" = "$expected_status" ]; then
        echo -e "\n${GREEN}✓ 測試通過${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "\n${RED}✗ 測試失敗 (期望狀態碼: $expected_status, 實際: $http_code)${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# ============================================================================
# 1. 基礎模型測試 - Claude Haiku
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  1. Claude Haiku 模型測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 1.1 Haiku 基礎測試（非流式）
run_test "Claude Haiku - 基礎非流式請求" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "Hello, this is a test message."}
    ],
    "max_tokens": 50,
    "stream": false
}'

# 1.2 Haiku 流式測試
run_test "Claude Haiku - 流式請求" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "Count from 1 to 5."}
    ],
    "max_tokens": 50,
    "stream": true
}'

# 1.3 Haiku 帶系統提示詞
run_test "Claude Haiku - 帶系統提示詞" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is 2+2?"}
    ],
    "max_tokens": 50,
    "stream": false
}'

# ============================================================================
# 2. Claude Sonnet 模型測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  2. Claude Sonnet 模型測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 2.1 Sonnet 3.5 基礎測試
run_test "Claude Sonnet 3.5 - 基礎請求" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    "max_tokens": 100,
    "stream": false
}'

# 2.2 Sonnet 3.5 流式
run_test "Claude Sonnet 3.5 - 流式請求" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "List 3 benefits of exercise."}
    ],
    "max_tokens": 100,
    "stream": true
}'

# 2.3 Sonnet 4
run_test "Claude Sonnet 4 - 基礎請求" '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
        {"role": "user", "content": "What is machine learning?"}
    ],
    "max_tokens": 100,
    "stream": false
}'

# 2.4 Sonnet 3.7 Thinking
run_test "Claude Sonnet 3.7 Thinking - 基礎請求" '{
    "model": "claude-3-7-sonnet-20250219:thinking",
    "messages": [
        {"role": "user", "content": "Solve: If a train travels 60 mph for 2 hours, how far does it go?"}
    ],
    "max_tokens": 200,
    "stream": false
}'

# ============================================================================
# 3. Claude Opus 模型測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  3. Claude Opus 模型測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 3.1 Opus 基礎測試
run_test "Claude Opus - 基礎請求" '{
    "model": "claude-3-opus-20240229",
    "messages": [
        {"role": "user", "content": "Write a short poem about AI."}
    ],
    "max_tokens": 150,
    "stream": false
}'

# 3.2 Opus 流式
run_test "Claude Opus - 流式請求" '{
    "model": "claude-3-opus-20240229",
    "messages": [
        {"role": "user", "content": "Explain the theory of relativity briefly."}
    ],
    "max_tokens": 200,
    "stream": true
}'

# ============================================================================
# 4. 參數組合測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  4. 參數組合測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 4.1 Temperature 參數
run_test "Temperature 參數測試" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "Generate a creative story idea."}
    ],
    "max_tokens": 100,
    "temperature": 0.9,
    "stream": false
}'

# 4.2 Top P 參數
run_test "Top P 參數測試" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "Write a random sentence."}
    ],
    "max_tokens": 50,
    "top_p": 0.95,
    "stream": false
}'

# 4.3 同時使用 Temperature 和 Top P
run_test "Temperature + Top P 組合測試" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "Suggest a unique name for a coffee shop."}
    ],
    "max_tokens": 50,
    "temperature": 0.8,
    "top_p": 0.9,
    "stream": false
}'

# 4.4 Stop Sequences
run_test "Stop Sequences 測試" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "List items: apple, banana"}
    ],
    "max_tokens": 100,
    "stop": ["orange"],
    "stream": false
}'

# ============================================================================
# 5. 多輪對話測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  5. 多輪對話測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 5.1 簡單多輪對話
run_test "多輪對話 - 簡單對話" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "My name is Alice."},
        {"role": "assistant", "content": "Hello Alice! Nice to meet you."},
        {"role": "user", "content": "What is my name?"}
    ],
    "max_tokens": 50,
    "stream": false
}'

# 5.2 複雜多輪對話
run_test "多輪對話 - 複雜對話" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "system", "content": "You are a helpful coding assistant."},
        {"role": "user", "content": "How do I create a function in Python?"},
        {"role": "assistant", "content": "You can create a function using the def keyword. For example: def my_function(): pass"},
        {"role": "user", "content": "Can you show me a more complete example?"}
    ],
    "max_tokens": 150,
    "stream": false
}'

# ============================================================================
# 6. 工具調用測試（Function Calling）
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  6. 工具調用測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 6.1 簡單工具調用
run_test "工具調用 - 簡單工具" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "What is the weather in San Francisco?"}
    ],
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "get_weather",
                "description": "Get the current weather in a given location",
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
                            "description": "The unit of temperature"
                        }
                    },
                    "required": ["location"]
                }
            }
        }
    ],
    "max_tokens": 200,
    "stream": false
}'

# 6.2 多工具調用
run_test "工具調用 - 多工具" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "Get the weather in Tokyo and convert 100 USD to JPY"}
    ],
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "get_weather",
                "description": "Get the current weather in a given location",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "location": {"type": "string", "description": "The city name"}
                    },
                    "required": ["location"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "convert_currency",
                "description": "Convert currency from one to another",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "amount": {"type": "number", "description": "The amount to convert"},
                        "from": {"type": "string", "description": "Source currency code"},
                        "to": {"type": "string", "description": "Target currency code"}
                    },
                    "required": ["amount", "from", "to"]
                }
            }
        }
    ],
    "max_tokens": 300,
    "stream": false
}'

# 6.3 Tool Choice - Required
run_test "工具調用 - Tool Choice Required" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "Calculate 15 * 23"}
    ],
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "calculator",
                "description": "Perform mathematical calculations",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "expression": {"type": "string", "description": "Mathematical expression"}
                    },
                    "required": ["expression"]
                }
            }
        }
    ],
    "tool_choice": "required",
    "max_tokens": 200,
    "stream": false
}'

# ============================================================================
# 7. 系統提示詞測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  7. 系統提示詞測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 7.1 簡單系統提示詞
run_test "系統提示詞 - 簡單提示詞" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "system", "content": "You are a friendly chatbot."},
        {"role": "user", "content": "Hello!"}
    ],
    "max_tokens": 50,
    "stream": false
}'

# 7.2 複雜系統提示詞
run_test "系統提示詞 - 複雜提示詞" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "system", "content": "You are an expert Python programmer. Always provide code examples with explanations. Use clear variable names and add comments."},
        {"role": "user", "content": "How do I read a CSV file?"}
    ],
    "max_tokens": 200,
    "stream": false
}'

# ============================================================================
# 8. 邊界情況測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  8. 邊界情況測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 8.1 最小 max_tokens
run_test "邊界情況 - 最小 max_tokens" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": "Say hi"}
    ],
    "max_tokens": 1,
    "stream": false
}'

# 8.2 大 max_tokens
run_test "邊界情況 - 大 max_tokens" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "Write a short story about a robot."}
    ],
    "max_tokens": 4096,
    "stream": false
}'

# 8.3 空消息
run_test "邊界情況 - 空消息內容" '{
    "model": "claude-3-haiku-20240307",
    "messages": [
        {"role": "user", "content": ""}
    ],
    "max_tokens": 50,
    "stream": false
}'

# 8.4 長消息
run_test "邊界情況 - 長消息" '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        {"role": "user", "content": "'"$(python3 -c "print('A' * 1000)")"'"}
    ],
    "max_tokens": 100,
    "stream": false
}'

# ============================================================================
# 9. 不同端點格式測試（如果支持）
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  9. 不同端點格式測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 9.1 測試 /v1/messages (Anthropic 格式)
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}測試 Anthropic 格式端點: /v1/messages${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

anthropic_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/v1/messages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_KEY}" \
    -d '{
        "model": "claude-3-haiku-20240307",
        "messages": [
            {"role": "user", "content": "Test Anthropic format endpoint"}
        ],
        "max_tokens": 50
    }')

anthropic_code=$(echo "$anthropic_response" | tail -n1)
anthropic_body=$(echo "$anthropic_response" | sed '$d')

echo "HTTP Status: $anthropic_code"
echo "$anthropic_body" | jq '.' 2>/dev/null || echo "$anthropic_body"

if [ "$anthropic_code" = "200" ]; then
    echo -e "\n${GREEN}✓ Anthropic 格式端點支持${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "\n${YELLOW}⚠ Anthropic 格式端點不支持或返回錯誤${NC}"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

# ============================================================================
# 10. 流式響應詳細測試
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  10. 流式響應詳細測試${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"

# 10.1 測試流式響應格式
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}測試流式響應格式${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

stream_response=$(curl -s -N \
    -X POST "${BASE_URL}${ENDPOINT}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_KEY}" \
    -d '{
        "model": "claude-3-haiku-20240307",
        "messages": [
            {"role": "user", "content": "Count from 1 to 3, one number per line."}
        ],
        "max_tokens": 50,
        "stream": true
    }')

echo "流式響應前 500 字符:"
echo "$stream_response" | head -c 500
echo -e "\n..."

# 檢查是否包含 SSE 格式
if echo "$stream_response" | grep -q "data:"; then
    echo -e "\n${GREEN}✓ 流式響應格式正確（SSE 格式）${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "\n${YELLOW}⚠ 流式響應格式可能不標準${NC}"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

# ============================================================================
# 測試總結
# ============================================================================

echo -e "\n\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  測試總結${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "總測試數: ${TOTAL}"
echo -e "${GREEN}通過: ${PASSED}${NC}"
echo -e "${RED}失敗: ${FAILED}${NC}"
echo -e "成功率: $(( PASSED * 100 / TOTAL ))%"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}\n"

# 生成測試報告
REPORT_FILE="clewdr-test-report-$(date +%Y%m%d-%H%M%S).json"
cat > "$REPORT_FILE" <<EOF
{
  "test_summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "success_rate": $(( PASSED * 100 / TOTAL )),
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "server_info": {
    "base_url": "$BASE_URL",
    "endpoint": "$ENDPOINT"
  }
}
EOF

echo -e "${BLUE}測試報告已保存到: ${REPORT_FILE}${NC}\n"

