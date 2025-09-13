#!/bin/bash

#===================================================================================================
# Tomcat GC 로그 출력 스크립트
# 사용법: ./show_gc_logs.sh <인스턴스명>
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
    echo "  $0 instance1                # Show GC logs for instance1"
    echo "  $0 instance2                # Show GC logs for instance2"
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

# Tomcat GC 로그 출력 함수
show_tomcat_gc_logs() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    # GCLOG_DIR을 배열로 변환
    local gclog_dir_array=($GCLOG_DIR)
    local instance_gclog_dir="${gclog_dir_array[$instance_index]}"
    
    # GC 로그 디렉토리 존재 확인
    if [ ! -d "$instance_gclog_dir" ]; then
        echo "GC log directory not found: $instance_gclog_dir"
        return 1
    fi
    
    echo "GC Log Directory: $instance_gclog_dir"
    echo ""
    
    # 최신 GC 로그 파일 찾기
    local recent_gclog=$(ls -t "$instance_gclog_dir"/gc*.log* 2>/dev/null | head -1)
    
    if [ -n "$recent_gclog" ] && [ -f "$recent_gclog" ]; then
        echo "Recent GC log file: $(basename "$recent_gclog")"
        echo "File size: $(du -h "$recent_gclog" | cut -f1 2>/dev/null || echo "Unknown")"
        echo ""
        tail -100 "$recent_gclog"
        return 0
    else
        echo "No GC log files found in directory: $instance_gclog_dir"
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
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    if [ "$instance_index" -eq -1 ]; then
        echo "Error: Tomcat instance '$instance_name' not found in configuration"
        echo "Available instances: ${TOMCAT_INST_NAME[@]}"
        echo "====================================================================================================="
        return 1
    fi
    
    echo "Tomcat GC Log for Instance: $instance_name"
    echo "====================================================================================================="
    
    # GC 로그 출력
    if ! show_tomcat_gc_logs "$instance_name"; then
        echo "No GC log files found for instance: $instance_name"
    fi
    
    echo "====================================================================================================="
    echo "Log display completed."
}

# 메인 함수 실행
main "$@"