#!/bin/bash

# Clewdr Claude 模型可用性測試腳本
# 目的：測試從外部呼叫 Clewdr 時，哪些 Claude 模型會成功返回

set -uo pipefail

# -----------------------------------------------------------------------------
# 配置
# -----------------------------------------------------------------------------
BASE_URL="${BASE_URL:-http://127.0.0.1:8484}"
API_KEY="${API_KEY:-k9rZeLu6tEHA9jQx43TkyUBTXP6NN2SuYVDtgkUxK5bTfUveCWm3BYnQPt4Br6zR}"
ENDPOINT="/v1/chat/completions"

# -----------------------------------------------------------------------------
# 顏色輸出
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# 測試統計
# -----------------------------------------------------------------------------
PASSED=0
FAILED=0
TOTAL=0
AVAILABLE_MODELS=()
UNAVAILABLE_MODELS=()

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

# 測試單個模型
test_model() {
    local model_name="$1"
    local display_name="$2"
    
    TOTAL=$((TOTAL + 1))
    print_test "$display_name (模型: $model_name)"
    
    local request_body
    request_body=$(cat <<EOF
{
    "model": "$model_name",
    "messages": [
        {"role": "user", "content": "Say 'Hello' in one word."}
    ],
    "max_tokens": 10,
    "stream": false
}
EOF
)
    
    echo -e "${YELLOW}請求模型:${NC} $model_name"
    
    local response
    local curl_exit_code=0
    response=$(curl -s -w "\n%{http_code}" --max-time 30 \
        -X POST "${BASE_URL}${ENDPOINT}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "$request_body" 2>&1) || curl_exit_code=$?
    
    if [ $curl_exit_code -ne 0 ]; then
        echo -e "${RED}✗ curl 請求失敗 (退出碼: $curl_exit_code)${NC}"
        echo "$response"
        FAILED=$((FAILED + 1))
        UNAVAILABLE_MODELS+=("$display_name ($model_name)")
        return 1
    fi
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local resp_body
    resp_body=$(echo "$response" | sed '$d')
    
    echo "HTTP Status: $http_code"
    
    # 檢查響應體是否包含錯誤
    local has_error=false
    if echo "$resp_body" | jq -e '.error' > /dev/null 2>&1; then
        has_error=true
        local error_msg
        error_msg=$(echo "$resp_body" | jq -r '.error.message // .error.type // "Unknown error"' 2>/dev/null || echo "Parse error")
        echo -e "${RED}錯誤: $error_msg${NC}"
    fi
    
    # 檢查是否成功（HTTP 200 且無錯誤，或有有效的 choices）
    if [ "$http_code" = "200" ] && [ "$has_error" = false ]; then
        # 進一步檢查是否有 choices 字段
        if echo "$resp_body" | jq -e '.choices' > /dev/null 2>&1; then
            local choice_count
            choice_count=$(echo "$resp_body" | jq '.choices | length' 2>/dev/null || echo "0")
            if [ "$choice_count" -gt 0 ]; then
                local content
                content=$(echo "$resp_body" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")
                echo -e "${GREEN}✓ 模型可用${NC}"
                if [ -n "$content" ]; then
                    echo -e "${CYAN}響應內容: $content${NC}"
                fi
                PASSED=$((PASSED + 1))
                AVAILABLE_MODELS+=("$display_name ($model_name)")
                return 0
            fi
        fi
    fi
    
    # 如果到達這裡，說明模型不可用
    echo -e "${RED}✗ 模型不可用${NC}"
    if [ -n "$resp_body" ]; then
        echo "$resp_body" | jq '.' 2>/dev/null || echo "$resp_body"
    fi
    FAILED=$((FAILED + 1))
    UNAVAILABLE_MODELS+=("$display_name ($model_name)")
    return 1
}

# -----------------------------------------------------------------------------
# 服務器連接檢查
# -----------------------------------------------------------------------------
echo -e "${BLUE}檢查服務器連接: ${BASE_URL}${NC}"
if ! curl -s --max-time 5 "${BASE_URL}" > /dev/null 2>&1; then
    echo -e "${RED}警告: 無法連接到服務器 ${BASE_URL}${NC}"
    echo -e "${YELLOW}請確認 Clewdr 服務器正在運行${NC}\n"
    exit 1
else
    echo -e "${GREEN}✓ 服務器連接正常${NC}\n"
fi

# -----------------------------------------------------------------------------
# 定義要測試的模型
# -----------------------------------------------------------------------------
print_section "Claude 模型可用性測試"

# 模型列表：格式為 "模型名稱|顯示名稱"
# 根據常見的命名模式，我們會測試多種可能的格式

MODELS=(
    # Claude Opus 系列
    "claude-opus-4-1-20250514|Claude Opus 4.1"
    "claude-4-1-opus-20250514|Claude Opus 4.1 (alt)"
    "claude-opus-4.1-20250514|Claude Opus 4.1 (alt2)"
    "claude-opus-4-20250514|Claude Opus 4"
    "claude-4-opus-20250514|Claude Opus 4 (alt)"
    "claude-3-opus-20240229|Claude Opus 3"
    
    # Claude Sonnet 系列
    "claude-sonnet-4-5-20250514|Claude Sonnet 4.5"
    "claude-4-5-sonnet-20250514|Claude Sonnet 4.5 (alt)"
    "claude-sonnet-4-5-20250101|Claude Sonnet 4.5 (alt2)"
    "claude-sonnet-4-20250514|Claude Sonnet 4"
    "claude-4-sonnet-20250514|Claude Sonnet 4 (alt)"
    "claude-3-7-sonnet-20250219|Claude Sonnet 3.7"
    "claude-3-5-sonnet-20241022|Claude Sonnet 3.5"
    
    # Claude Haiku 系列
    "claude-haiku-4-5-20250514|Claude Haiku 4.5"
    "claude-4-5-haiku-20250514|Claude Haiku 4.5 (alt)"
    "claude-haiku-4-5-20250101|Claude Haiku 4.5 (alt2)"
    "claude-3-5-haiku-20241022|Claude Haiku 3.5"
    "claude-haiku-3-5-20241022|Claude Haiku 3.5 (alt)"
    "claude-3-haiku-20240307|Claude Haiku 3"
)

# -----------------------------------------------------------------------------
# 執行測試
# -----------------------------------------------------------------------------
for model_entry in "${MODELS[@]}"; do
    IFS='|' read -r model_name display_name <<< "$model_entry"
    test_model "$model_name" "$display_name"
done

# -----------------------------------------------------------------------------
# 測試總結
# -----------------------------------------------------------------------------
print_section "測試總結"

echo -e "總測試數: ${TOTAL}"
echo -e "${GREEN}可用模型數: ${#AVAILABLE_MODELS[@]}${NC}"
echo -e "${RED}不可用模型數: ${#UNAVAILABLE_MODELS[@]}${NC}"

if [ "$TOTAL" -gt 0 ]; then
    SUCCESS_RATE=$(( PASSED * 100 / TOTAL ))
    echo -e "成功率: ${SUCCESS_RATE}%"
fi

# 顯示可用模型列表
if [ ${#AVAILABLE_MODELS[@]} -gt 0 ]; then
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  可用的模型：${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
    for model in "${AVAILABLE_MODELS[@]}"; do
        echo -e "${GREEN}✓ $model${NC}"
    done
fi

# 顯示不可用模型列表
if [ ${#UNAVAILABLE_MODELS[@]} -gt 0 ]; then
    echo -e "\n${RED}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  不可用的模型：${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════════════════════${NC}"
    for model in "${UNAVAILABLE_MODELS[@]}"; do
        echo -e "${RED}✗ $model${NC}"
    done
fi

# -----------------------------------------------------------------------------
# 生成 JSON 測試報告
# -----------------------------------------------------------------------------
REPORT_FILE="claude-model-test-report-$(date +%Y%m%d-%H%M%S).json"

# 構建 JSON 數組
if [ ${#AVAILABLE_MODELS[@]} -eq 0 ]; then
    AVAILABLE_JSON="[]"
else
    AVAILABLE_JSON="["
    for i in "${!AVAILABLE_MODELS[@]}"; do
        if [ $i -gt 0 ]; then
            AVAILABLE_JSON+=","
        fi
        # 轉義 JSON 特殊字符
        escaped=$(echo "${AVAILABLE_MODELS[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        AVAILABLE_JSON+="\"$escaped\""
    done
    AVAILABLE_JSON+="]"
fi

if [ ${#UNAVAILABLE_MODELS[@]} -eq 0 ]; then
    UNAVAILABLE_JSON="[]"
else
    UNAVAILABLE_JSON="["
    for i in "${!UNAVAILABLE_MODELS[@]}"; do
        if [ $i -gt 0 ]; then
            UNAVAILABLE_JSON+=","
        fi
        # 轉義 JSON 特殊字符
        escaped=$(echo "${UNAVAILABLE_MODELS[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        UNAVAILABLE_JSON+="\"$escaped\""
    done
    UNAVAILABLE_JSON+="]"
fi

cat > "$REPORT_FILE" <<EOF
{
  "test_summary": {
    "total": $TOTAL,
    "available": ${#AVAILABLE_MODELS[@]},
    "unavailable": ${#UNAVAILABLE_MODELS[@]},
    "success_rate": ${SUCCESS_RATE:-0},
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "server_info": {
    "base_url": "$BASE_URL",
    "endpoint": "$ENDPOINT"
  },
  "available_models": $AVAILABLE_JSON,
  "unavailable_models": $UNAVAILABLE_JSON
}
EOF

echo -e "\n${BLUE}測試報告已輸出至: ${REPORT_FILE}${NC}\n"

