#!/bin/bash

#===================================================================================================
# Tomcat 인스턴스 기동 스크립트
# 사용법: ./start_tomcat.sh <인스턴스명>
#   인스턴스명: Tomcat 인스턴스 이름 (예: instance1, instance2)
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
# Tomcat 기동스크립트 경로 패턴
STARTUP_SCRIPT_BASE="${TOMCAT_HOME}/servers"

# 기동 전 대기 시간 (초)
STARTUP_WAIT_TIME=3


#===================================================================================================

# 사용법 출력 함수
usage() {
    echo "Usage: $0 <instance_name>"
    echo ""
    echo "Parameters:"
    echo "  instance_name    Tomcat instance name (e.g., instance1, instance2)"
    echo ""
    echo "Available instances from configuration:"
    echo "  Tomcat instances: ${TOMCAT_INST_NAME[@]}"
    echo ""
    echo "Configuration:"
    echo "  Tomcat Home: $TOMCAT_HOME"
    echo "  Startup Script Base: $STARTUP_SCRIPT_BASE"
    echo ""
    echo "Examples:"
    echo "  $0 instance1                # Start Tomcat instance1"
    echo "  $0 instance2                # Start Tomcat instance2"
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


# Tomcat 인스턴스 기동 함수
start_tomcat_instance() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
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
        echo "Please check the STARTUP_SCRIPT_BASE configuration"
        return 1
    fi
    
    echo "Starting Tomcat instance: $instance_name"
    echo "Executing: $startup_script"
    echo ""
    
    # 기동 전 대기
    if [ "$STARTUP_WAIT_TIME" -gt 0 ]; then
        echo "Waiting ${STARTUP_WAIT_TIME} seconds before startup..."
        sleep "$STARTUP_WAIT_TIME"
    fi
    
    # Tomcat 기동 실행
    if "$startup_script"; then
        echo ""
        echo "✓ Tomcat startup script executed successfully"
        
        # 포트 정보 출력
        local shutdown_port="${TOMCAT_SDOWN_PORT[$instance_index]}"
        local http_port="${TOMCAT_HTTP_PORT[$instance_index]}"
        local ajp_port="${TOMCAT_AJP_PORT[$instance_index]}"
        
        if [ "$shutdown_port" != "-" ] && [ -n "$shutdown_port" ]; then
            echo "✓ Configured Shutdown Port: $shutdown_port"
        fi
        
        if [ "$http_port" != "-" ] && [ -n "$http_port" ]; then
            echo "✓ Configured HTTP Port: $http_port"
        fi
        
        if [ "$ajp_port" != "-" ] && [ -n "$ajp_port" ]; then
            echo "✓ Configured AJP Port: $ajp_port"
        fi
        
        return 0
    else
        echo ""
        echo "Error: Startup script execution failed"
        echo "Please check the Tomcat logs for details"
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
    echo "Tomcat Instance Startup"
    echo "Instance: $instance_name"
    echo "Date: $(date)"
    echo "====================================================================================================="
    
    # 인스턴스 존재 여부 확인
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    if [ "$instance_index" -eq -1 ]; then
        echo "Error: Tomcat instance '$instance_name' not found in configuration"
        echo "Available instances: ${TOMCAT_INST_NAME[@]}"
        echo "====================================================================================================="
        return 1
    fi
    
    # Tomcat 인스턴스 기동
    if start_tomcat_instance "$instance_name"; then
        echo ""
        echo "====================================================================================================="
        echo "Tomcat startup completed successfully"
        echo "====================================================================================================="
    else
        echo ""
        echo "====================================================================================================="
        echo "Tomcat startup failed or completed with warnings"
        echo "====================================================================================================="
        return 1
    fi
}

# 메인 함수 실행
main "$@"