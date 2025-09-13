#!/bin/bash

#===================================================================================================
# Tomcat Engine 로그 출력 스크립트
# 사용법: ./show_tomcat_engine_logs.sh <인스턴스명>
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
    echo "Examples:"
    echo "  $0 instance1                # Show engine logs for instance1"
    echo "  $0 instance2                # Show engine logs for instance2"
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

# Tomcat catalina.out 로그 출력 함수
show_catalina_out_logs() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    # TOMCAT_LOG_DIR을 배열로 변환
    local tomcat_log_dir_array=($TOMCAT_LOG_DIR)
    local instance_log_dir="${tomcat_log_dir_array[$instance_index]}"
    local catalina_out="${instance_log_dir}/catalina.out"
    
    if [ -f "$catalina_out" ]; then
        echo "Catalina.out file: $catalina_out"
        echo "File size: $(du -h "$catalina_out" | cut -f1 2>/dev/null || echo "Unknown")"
        echo ""
        tail -100 "$catalina_out"
        return 0
    fi
    
    return 1
}

# Tomcat localhost.*.log 로그 출력 함수
show_localhost_logs() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    # TOMCAT_LOG_DIR을 배열로 변환
    local tomcat_log_dir_array=($TOMCAT_LOG_DIR)
    local instance_log_dir="${tomcat_log_dir_array[$instance_index]}"
    
    # 최신 localhost.*.log 파일 찾기
    local recent_localhost_log=$(ls -t "${instance_log_dir}"/localhost.*.log 2>/dev/null | head -1)
    
    if [ -n "$recent_localhost_log" ] && [ -f "$recent_localhost_log" ]; then
        echo "Recent localhost log file: $(basename "$recent_localhost_log")"
        echo "File size: $(du -h "$recent_localhost_log" | cut -f1 2>/dev/null || echo "Unknown")"
        echo ""
        tail -100 "$recent_localhost_log"
        return 0
    fi
    
    return 1
}

# Tomcat Engine 로그 출력 함수
show_tomcat_engine_logs() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    # TOMCAT_LOG_DIR을 배열로 변환
    local tomcat_log_dir_array=($TOMCAT_LOG_DIR)
    local instance_log_dir="${tomcat_log_dir_array[$instance_index]}"
    
    # Tomcat 로그 디렉토리 존재 확인
    if [ ! -d "$instance_log_dir" ]; then
        echo "Tomcat log directory not found: $instance_log_dir"
        return 1
    fi
    
    echo "Tomcat Log Directory: $instance_log_dir"
    echo ""
    
    local catalina_shown=false
    local localhost_shown=false
    
    # catalina.out 로그 출력
    if show_catalina_out_logs "$instance_name"; then
        catalina_shown=true
    fi
    
    # localhost.*.log 로그 출력 (catalina.out이 출력되었으면 구분선 추가)
    if show_localhost_logs "$instance_name"; then
        if [ "$catalina_shown" = true ]; then
            echo ""
            echo "-----------------------------------------------------------------------------------------------------"
        fi
        localhost_shown=true
    fi
    
    # 로그가 하나도 없는 경우
    if [ "$catalina_shown" = false ] && [ "$localhost_shown" = false ]; then
        echo "No engine log files found for instance: $instance_name"
        echo "Expected files: catalina.out, localhost.*.log"
        return 1
    fi
    
    return 0
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
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    if [ "$instance_index" -eq -1 ]; then
        echo "Error: Tomcat instance '$instance_name' not found in configuration"
        echo "Available instances: ${TOMCAT_INST_NAME[@]}"
        echo "====================================================================================================="
        return 1
    fi
    
    echo "Tomcat Engine Log for Instance: $instance_name"
    echo "====================================================================================================="
    
    # Engine 로그 출력
    if ! show_tomcat_engine_logs "$instance_name"; then
        echo "No engine log files found for instance: $instance_name"
    fi
    
    echo "====================================================================================================="
    echo "Log display completed."
}

# 메인 함수 실행
main "$@"