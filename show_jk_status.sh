#!/bin/bash

#===================================================================================================
# Apache jk-status 출력 스크립트
# 사용법: ./show_jkstatus_logs.sh <인스턴스명>
#   인스턴스명: Apache 인스턴스 이름 (예: instance1, instance2)
#===================================================================================================

# 환경 설정 파일 로드
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
ENV_FILE="${SCRIPT_DIR}/web_mon_cron.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file not found: $ENV_FILE"
    exit 1
fi

# 환경 변수 로드
source "$ENV_FILE"

# 사용법 출력 함수
usage() {
    echo "Usage: $0 <instance_name>"
    echo ""
    echo "Parameters:"
    echo "  instance_name    Apache instance name (e.g., instance1, instance2)"
    echo ""
    echo "Available instances from configuration:"
    echo "  Apache instances: ${APACHE_INST_NAME[@]}"
    echo ""
    echo "Examples:"
    echo "  $0 instance1                # Show jk-status for instance1"
    echo "  $0 instance2                # Show jk-status for instance2"
    exit 1
}

# 인스턴스 인덱스 찾기 함수
find_instance_index() {
    local instance_name="$1"
    local instance_array=("${@:2}")
    
    for i in "${!instance_array[@]}"; do
        if [ "${instance_array[$i]}" = "$instance_name" ]; then
            echo $i
            return 0
        fi
    done
    echo -1
}

# Apache jk-status 출력 함수
show_apache_jkstatus() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${APACHE_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    local http_port="${APACHE_HTTP_PORT[$instance_index]}"
    
    if [ "$http_port" != "-" ] && [ -n "$http_port" ]; then
        local jkstatus_url="http://${http_port}/jk-status"
        echo "jk-status URL: $jkstatus_url"
        echo ""
        
        # curl 명령어 존재 여부 확인
        if command -v curl >/dev/null 2>&1; then
            # curl을 사용하여 jk-status 요청
            if curl -s --connect-timeout 10 --max-time 30 \
                   -H "User-Agent: Apache-Monitor-Script" \
                   "$jkstatus_url" 2>/dev/null; then
                return 0
            else
                echo "Error: Failed to retrieve jk-status from $jkstatus_url"
                echo "Possible causes:"
                echo "- Apache server is not running"
                echo "- mod_jk module is not enabled"
                echo "- jk-status is not configured"
                echo "- Network connectivity issues"
                echo "- Access restrictions on jk-status"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            # wget을 사용하여 jk-status 요청 (curl이 없는 경우)
            if wget -q --timeout=30 --tries=1 \
                   --user-agent="Apache-Monitor-Script" \
                   -O - "$jkstatus_url" 2>/dev/null; then
                return 0
            else
                echo "Error: Failed to retrieve jk-status from $jkstatus_url"
                echo "Possible causes:"
                echo "- Apache server is not running"
                echo "- mod_jk module is not enabled"
                echo "- jk-status is not configured"
                echo "- Network connectivity issues"
                echo "- Access restrictions on jk-status"
                return 1
            fi
        else
            echo "Error: Neither curl nor wget is available for HTTP requests"
            return 1
        fi
    else
        echo "Error: HTTP port not configured for instance: $instance_name"
        return 1
    fi
}


# 메인 스크립트 로직
main() {
    # 파라미터 검증
    if [ $# -ne 1 ]; then
        usage
    fi
    
    local instance_name="$1"
    
    echo "====================================================================================================="
    echo "Instance: $instance_name"
    
    # 인스턴스 존재 여부 확인
    local instance_index=$(find_instance_index "$instance_name" "${APACHE_INST_NAME[@]}")
    if [ "$instance_index" -eq -1 ]; then
        echo "Error: Apache instance '$instance_name' not found in configuration"
        echo "Available instances: ${APACHE_INST_NAME[@]}"
        echo "====================================================================================================="
        return 1
    fi
    
    echo "Apache jk-status for Instance: $instance_name"
    echo "====================================================================================================="
    
    # jk-status 출력
    if ! show_apache_jkstatus "$instance_name"; then
        echo ""
        echo "Unable to retrieve jk-status for instance: $instance_name"
    fi
    
    echo "====================================================================================================="
    echo "Status display completed."
}

# 메인 함수 실행
main "$@"