#!/bin/bash

#===================================================================================================
# Tomcat 인스턴스 중지 스크립트
# 사용법: ./stop_tomcat.sh <인스턴스명>
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
# Tomcat 중지스크립트 경로 패턴
STOP_SCRIPT_BASE="${TOMCAT_HOME}/servers"

# 중지 전 대기 시간 (초)
STOP_WAIT_TIME=3


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
    echo "  Stop Script Base: $STOP_SCRIPT_BASE"
    echo ""
    echo "Examples:"
    echo "  $0 instance1                # Stop Tomcat instance1"
    echo "  $0 instance2                # Stop Tomcat instance2"
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


# Tomcat 인스턴스 중지 함수
stop_tomcat_instance() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    # 중지스크립트 경로 생성
    local stop_script="${STOP_SCRIPT_BASE}/${instance_name}/shl/stop.sh"
    
    echo "Stop Script: $stop_script"
    echo ""
    
    # 스크립트 존재 여부 확인
    if [ ! -f "$stop_script" ]; then
        echo "Error: Stop script not found: $stop_script"
        echo "Please check the STOP_SCRIPT_BASE configuration"
        return 1
    fi
    
    echo "Stopping Tomcat instance: $instance_name"
    echo "Executing: $stop_script"
    echo ""
    
    # 중지 전 대기
    if [ "$STOP_WAIT_TIME" -gt 0 ]; then
        echo "Waiting ${STOP_WAIT_TIME} seconds before stopping..."
        sleep "$STOP_WAIT_TIME"
    fi
    
    # Tomcat 중지 실행
    if "$stop_script"; then
        echo ""
        echo "✓ Tomcat stop script executed successfully"
        
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
        echo "Error: Stop script execution failed"
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
    echo "Tomcat Instance Stop"
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
    
    # Tomcat 인스턴스 중지
    if stop_tomcat_instance "$instance_name"; then
        echo ""
        echo "====================================================================================================="
        echo "Tomcat stop completed successfully"
        echo "====================================================================================================="
    else
        echo ""
        echo "====================================================================================================="
        echo "Tomcat stop failed or completed with warnings"
        echo "====================================================================================================="
        return 1
    fi
}

# 메인 함수 실행
main "$@"