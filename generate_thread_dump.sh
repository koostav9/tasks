#!/bin/bash

#===================================================================================================
# Java Thread Dump 생성 및 출력 스크립트
# 사용법: ./generate_thread_dump.sh <인스턴스명>
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
# Thread Dump 생성 스크립트 경로
TDUMP_SCRIPT="${TOMCAT_HOME}/shl/tdump.sh"

# Thread Dump 저장 경로
DUMP_DIR="~/dump"

# Dump 생성 후 대기 시간 (초) - tdump.sh가 3개 파일을 생성하는 시간 고려
DUMP_WAIT_TIME=12


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
    echo "  Thread Dump Script: $TDUMP_SCRIPT"
    echo "  Dump Directory: $DUMP_DIR"
    echo ""
    echo "Examples:"
    echo "  $0 instance1                # Generate thread dump for instance1"
    echo "  $0 instance2                # Generate thread dump for instance2"
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

# Thread Dump 생성 함수
generate_thread_dump() {
    local instance_name="$1"
    local instance_index=$(find_instance_index "$instance_name" "${TOMCAT_INST_NAME[@]}")
    
    if [ "$instance_index" -eq -1 ]; then
        return 1
    fi
    
    echo "Thread Dump Script: $TDUMP_SCRIPT"
    echo "Target Instance: $instance_name"
    echo "Dump Directory: $DUMP_DIR"
    echo ""
    
    # tdump.sh 스크립트 존재 여부 확인
    if [ ! -f "$TDUMP_SCRIPT" ]; then
        echo "Error: Thread dump script not found: $TDUMP_SCRIPT"
        echo "Please check the TOMCAT_HOME configuration"
        return 1
    fi
    
    # Dump 디렉토리 확장 (~ 처리)
    local expanded_dump_dir=$(eval echo "$DUMP_DIR")
    
    echo "Generating thread dumps for instance: $instance_name"
    echo "Executing: $TDUMP_SCRIPT $instance_name"
    echo ""
    echo "Note: tdump.sh will generate 3 dump files with 3-second intervals"
    echo "Please wait for completion..."
    echo ""
    
    # Thread Dump 생성 실행
    if "$TDUMP_SCRIPT" "$instance_name"; then
        echo ""
        echo "✓ Thread dump generation completed successfully"
        echo ""
        
        # 생성 완료 대기 (추가 안전 시간)
        echo "Waiting ${DUMP_WAIT_TIME} seconds for dump generation to complete..."
        sleep "$DUMP_WAIT_TIME"
        
        return 0
    else
        echo ""
        echo "Error: Thread dump generation failed"
        echo "Please check the Tomcat instance status and logs"
        return 1
    fi
}

# 생성된 Thread Dump 파일 출력 함수
show_thread_dumps() {
    local instance_name="$1"
    local expanded_dump_dir=$(eval echo "$DUMP_DIR")
    
    echo "Searching for thread dump files in: $expanded_dump_dir"
    echo ""
    
    # 최근 생성된 thread dump 파일들 찾기 (최근 5분 이내)
    local recent_dumps=$(find "$expanded_dump_dir" -name "*${instance_name}*" -type f -mmin -5 2>/dev/null | sort -t)
    
    if [ -z "$recent_dumps" ]; then
        # 인스턴스명 패턴으로 찾지 못한 경우 일반적인 패턴으로 재시도
        recent_dumps=$(find "$expanded_dump_dir" -name "*.dump" -o -name "*thread*" -o -name "*tdump*" 2>/dev/null | head -10 | sort -t)
    fi
    
    if [ -n "$recent_dumps" ]; then
        echo "Found thread dump files:"
        echo "-----------------------------------------------------------------------------------------------------"
        
        local file_count=0
        while IFS= read -r dump_file; do
            if [ -f "$dump_file" ]; then
                file_count=$((file_count + 1))
                echo "[$file_count] File: $(basename "$dump_file")"
                echo "    Path: $dump_file"
                echo "    Size: $(du -h "$dump_file" | cut -f1 2>/dev/null || echo "Unknown")"
                echo "    Modified: $(stat -c %y "$dump_file" 2>/dev/null || stat -f %Sm "$dump_file" 2>/dev/null || echo "Unknown")"
                echo ""
                
                # 각 파일의 전체 내용 출력
                echo "Content of dump file [$file_count]:"
                echo "= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
                cat "$dump_file" 2>/dev/null
                echo "= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
                echo ""
            fi
        done <<< "$recent_dumps"
        
        return 0
    else
        echo "No recent thread dump files found for instance: $instance_name"
        echo "Expected location: $expanded_dump_dir"
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
    echo "Java Thread Dump Generation"
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
    
    # Thread Dump 생성
    if generate_thread_dump "$instance_name"; then
        echo "====================================================================================================="
        echo "Generated Thread Dump Files"
        echo "====================================================================================================="
        
        # 생성된 Thread Dump 파일 출력
        if ! show_thread_dumps "$instance_name"; then
            echo "Thread dump generation completed, but files may not be immediately visible"
        fi
    else
        echo "====================================================================================================="
        echo "Thread dump generation failed"
        echo "====================================================================================================="
        return 1
    fi
    
    echo "====================================================================================================="
    echo "Thread dump process completed"
    echo "====================================================================================================="
}

# 메인 함수 실행
main "$@"