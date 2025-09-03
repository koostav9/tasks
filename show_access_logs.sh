#!/bin/bash

#===================================================================================================
# Apache HTTP Server Access 로그 출력 스크립트
# 사용법: ./show_access_logs.sh <인스턴스명>
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
    echo "  $0 instance1                # Show HTTP access logs for instance1"
    echo "  $0 instance2                # Show HTTP access logs for instance2"
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

# Apache HTTP access 로그 출력 함수
show_apache_http_logs() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${APACHE_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    local http_alog="${APACHE_HTTP_ALOG[$instance_index]}"
    
    if [ "$http_alog" != "-" ] && [ -n "$http_alog" ] && [ -f "$http_alog" ]; then
        echo "HTTP Log file: $http_alog"
        echo ""
        tail -100 "$http_alog"
        return 0
    fi
    
    return 1
}

# Apache HTTPS access 로그 출력 함수
show_apache_https_logs() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${APACHE_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    local https_alog="${APACHE_HTTPS_ALOG[$instance_index]}"
    
    if [ "$https_alog" != "-" ] && [ -n "$https_alog" ] && [ -f "$https_alog" ]; then
        echo "HTTPS Log file: $https_alog"
        echo ""
        tail -100 "$https_alog"
        return 0
    fi
    
    return 1
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
    
    echo "Apache Access Log for Instance: $instance_name"
    echo "====================================================================================================="
    
    local http_shown=false
    local https_shown=false
    
    # HTTP 로그 출력
    if show_apache_http_logs "$instance_name"; then
        http_shown=true
    fi
    
    # HTTPS 로그 출력 (HTTP 로그가 출력되었으면 구분선 추가)
    if show_apache_https_logs "$instance_name"; then
        if [ "$http_shown" = true ]; then
            echo ""
            echo "-----------------------------------------------------------------------------------------------------"
        fi
        https_shown=true
    fi
    
    # 로그가 하나도 없는 경우
    if [ "$http_shown" = false ] && [ "$https_shown" = false ]; then
        echo "No access log files found for instance: $instance_name"
    fi
    
    echo "====================================================================================================="
    echo "Log display completed."
}

# 메인 함수 실행
main "$@"