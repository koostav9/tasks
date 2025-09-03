#!/bin/bash

#===================================================================================================
# Apache 인스턴스 기동 스크립트
# 사용법: ./start_apache.sh <인스턴스명>
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

#===================================================================================================
# 사용자 설정 변수 (필요에 따라 수정 가능)
#===================================================================================================
# Apache 기동스크립트 경로 패턴
STARTUP_SCRIPT_BASE="${APACHE_HOME}/servers"

# 기동 전 대기 시간 (초)
STARTUP_WAIT_TIME=3


#===================================================================================================

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
    echo "Configuration:"
    echo "  Apache Home: $APACHE_HOME"
    echo "  Startup Script Base: $STARTUP_SCRIPT_BASE"
    echo ""
    echo "Examples:"
    echo "  $0 instance1                # Start Apache instance1"
    echo "  $0 instance2                # Start Apache instance2"
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


# Apache 인스턴스 시작 함수
start_apache_instance() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${APACHE_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    # 기동스크립트 경로 생성
    local startup_script="${STARTUP_SCRIPT_BASE}/${instance_name}/shl/start.sh"
    
    echo "Startup Script: $startup_script"
    echo ""
    
    # 스크립트 존재 여부 확인
    if [ ! -f "$startup_script" ]; then
        echo "Error: Startup script not found: $startup_script"
        echo "Please check the STARTUP_SCRIPT_PATH configuration"
        return 1
    fi
    
    echo "Starting Apache instance: $instance_name"
    echo "Executing: $startup_script"
    echo ""
    
    # 기동 전 대기
    if [ "$STARTUP_WAIT_TIME" -gt 0 ]; then
        echo "Waiting ${STARTUP_WAIT_TIME} seconds before startup..."
        sleep "$STARTUP_WAIT_TIME"
    fi
    
    # Apache 기동 실행
    if "$startup_script"; then
        echo ""
        echo "✓ Apache startup script executed successfully"
        
        # 포트 정보 출력
        local http_port="${APACHE_HTTP_PORT[$instance_index]}"
        if [ "$http_port" != "-" ] && [ -n "$http_port" ]; then
            echo "✓ Configured HTTP Port: $http_port"
        fi
        
        return 0
    else
        echo ""
        echo "Error: Startup script execution failed"
        echo "Please check the Apache logs for details"
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
    echo "Apache Instance Startup"
    echo "Instance: $instance_name"
    echo "Date: $(date)"
    echo "====================================================================================================="
    
    # 인스턴스 존재 여부 확인
    local instance_index=$(find_instance_index "$instance_name" "${APACHE_INST_NAME[@]}")
    if [ "$instance_index" -eq -1 ]; then
        echo "Error: Apache instance '$instance_name' not found in configuration"
        echo "Available instances: ${APACHE_INST_NAME[@]}"
        echo "====================================================================================================="
        return 1
    fi
    
    # Apache 인스턴스 시작
    if start_apache_instance "$instance_name"; then
        echo ""
        echo "====================================================================================================="
        echo "Apache startup completed successfully"
        echo "====================================================================================================="
    else
        echo ""
        echo "====================================================================================================="
        echo "Apache startup failed or completed with warnings"
        echo "====================================================================================================="
        return 1
    fi
}

# 메인 함수 실행
main "$@"