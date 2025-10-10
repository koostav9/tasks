#!/bin/bash

#===================================================================================================
# Apache httpd.conf 설정 파일 출력 스크립트
# 사용법: ./show_httpd_conf.sh
# 실행중인 httpd 프로세스가 참조하는 httpd.conf 파일을 찾아서 내용을 출력합니다.
# httpd.conf 내부에서 참조하는 설정파일들도 재귀적으로 출력합니다.
#===================================================================================================

# 사용법 출력 함수
usage() {
    echo "Usage: $0"
    echo ""
    echo "Description:"
    echo "  This script finds running httpd processes and displays their httpd.conf file contents."
    echo "  It also recursively displays included configuration files."
    echo "  Comments (lines starting with '#') are filtered out from the output."
    echo ""
    echo "Examples:"
    echo "  $0                          # Show httpd.conf for all running httpd processes"
    exit 1
}

# 중복 제거된 httpd.conf 파일 목록을 찾는 함수
find_httpd_conf_files() {
    local conf_files=()

    # 실행중인 httpd 프로세스를 찾아서 httpd.conf 파일 경로 추출
    echo "Searching for running httpd processes..."
    echo ""

    # ps 명령어로 현재 사용자의 httpd 프로세스 찾기
    local httpd_processes=$(ps -ef | grep $(whoami) | grep httpd | grep -v grep)

    if [ -z "$httpd_processes" ]; then
        echo "No running httpd processes found for user: $(whoami)"
        return 1
    fi

    echo "Found httpd processes:"
    echo "$httpd_processes"
    echo ""

    # 각 httpd 프로세스에서 -f 옵션으로 지정된 설정파일 경로 추출
    while IFS= read -r process_line; do
        if [ -n "$process_line" ]; then
            # -f 옵션 뒤의 설정파일 경로 추출
            local conf_path=$(echo "$process_line" | sed -n 's/.*-f *\([^ ]*\).*/\1/p')

            if [ -n "$conf_path" ] && [ -f "$conf_path" ]; then
                # 중복 제거를 위해 배열에 추가 (이미 존재하는지 확인)
                local already_exists=false
                for existing_conf in "${conf_files[@]}"; do
                    if [ "$existing_conf" = "$conf_path" ]; then
                        already_exists=true
                        break
                    fi
                done

                if [ "$already_exists" = false ]; then
                    conf_files+=("$conf_path")
                fi
            else
                # -f 옵션이 없는 경우 기본 경로들 확인
                local default_paths=(
                    "/etc/httpd/conf/httpd.conf"
                    "/etc/apache2/httpd.conf"
                    "/usr/local/apache2/conf/httpd.conf"
                    "/opt/apache2/conf/httpd.conf"
                )

                for default_path in "${default_paths[@]}"; do
                    if [ -f "$default_path" ]; then
                        local already_exists=false
                        for existing_conf in "${conf_files[@]}"; do
                            if [ "$existing_conf" = "$default_path" ]; then
                                already_exists=true
                                break
                            fi
                        done

                        if [ "$already_exists" = false ]; then
                            conf_files+=("$default_path")
                        fi
                        break
                    fi
                done
            fi
        fi
    done <<< "$httpd_processes"

    # 찾은 설정파일 목록 출력
    if [ ${#conf_files[@]} -eq 0 ]; then
        echo "No httpd.conf files found for running httpd processes"
        return 1
    fi

    echo "Found httpd.conf files:"
    for conf_file in "${conf_files[@]}"; do
        echo "  $conf_file"
    done
    echo ""

    # 전역 변수로 설정
    HTTPD_CONF_FILES=("${conf_files[@]}")
    return 0
}

# 설정파일에서 Include 지시어로 참조되는 파일들을 재귀적으로 찾는 함수
find_included_files() {
    local config_file="$1"
    local included_files=()

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Include, IncludeOptional 지시어 찾기 (주석이 아닌 라인만)
    local includes=$(grep -E "^[[:space:]]*Include(Optional)?[[:space:]]" "$config_file" | sed 's/^[[:space:]]*//' | awk '{print $2}')

    while IFS= read -r include_path; do
        if [ -n "$include_path" ]; then
            # 상대경로인 경우 httpd.conf의 디렉토리를 기준으로 절대경로 변환
            if [[ "$include_path" != /* ]]; then
                local config_dir=$(dirname "$config_file")
                include_path="$config_dir/$include_path"
            fi

            # 와일드카드 패턴 처리
            if [[ "$include_path" == *"*"* ]]; then
                local wildcard_files=$(ls $include_path 2>/dev/null)
                while IFS= read -r wildcard_file; do
                    if [ -f "$wildcard_file" ]; then
                        included_files+=("$wildcard_file")
                        # 재귀적으로 포함된 파일들도 찾기
                        local nested_includes=$(find_included_files "$wildcard_file")
                        if [ -n "$nested_includes" ]; then
                            while IFS= read -r nested_file; do
                                if [ -n "$nested_file" ]; then
                                    included_files+=("$nested_file")
                                fi
                            done <<< "$nested_includes"
                        fi
                    fi
                done <<< "$wildcard_files"
            else
                if [ -f "$include_path" ]; then
                    included_files+=("$include_path")
                    # 재귀적으로 포함된 파일들도 찾기
                    local nested_includes=$(find_included_files "$include_path")
                    if [ -n "$nested_includes" ]; then
                        while IFS= read -r nested_file; do
                            if [ -n "$nested_file" ]; then
                                included_files+=("$nested_file")
                            fi
                        done <<< "$nested_includes"
                    fi
                fi
            fi
        fi
    done <<< "$includes"

    # 결과 출력
    for file in "${included_files[@]}"; do
        echo "$file"
    done
}

# 설정파일 내용을 주석 제거하여 출력하는 함수
display_config_file() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file not found: $config_file"
        return 1
    fi

    echo "Configuration File: $config_file"
    echo "-----------------------------------------------------------------------------------------------------"

    # 주석이 포함된 라인 제거 (# 으로 시작하는 라인과 공백 후 # 으로 시작하는 라인)
    grep -v "^[[:space:]]*#" "$config_file" | grep -v "^[[:space:]]*$"

    echo ""
}

# 메인 스크립트 로직
main() {
    # 파라미터 검증 (파라미터가 있으면 사용법 출력)
    if [ $# -gt 0 ]; then
        usage
    fi

    echo "====================================================================================================="
    echo "Apache httpd.conf Configuration Display"
    echo "====================================================================================================="

    # 실행중인 httpd 프로세스의 설정파일들 찾기
    if ! find_httpd_conf_files; then
        echo "====================================================================================================="
        return 1
    fi

    # 각 httpd.conf 파일과 포함된 설정파일들 출력
    for conf_file in "${HTTPD_CONF_FILES[@]}"; do
        echo "====================================================================================================="
        echo "Processing httpd.conf: $conf_file"
        echo "====================================================================================================="

        # 메인 설정파일 출력
        display_config_file "$conf_file"

        # 포함된 설정파일들 찾기 및 출력
        echo "Searching for included configuration files..."
        local included_files=$(find_included_files "$conf_file")

        if [ -n "$included_files" ]; then
            echo "Found included files:"
            while IFS= read -r included_file; do
                if [ -n "$included_file" ]; then
                    echo "  $included_file"
                fi
            done <<< "$included_files"
            echo ""

            # 각 포함된 파일 출력
            while IFS= read -r included_file; do
                if [ -n "$included_file" ]; then
                    echo "====================================================================================================="
                    display_config_file "$included_file"
                fi
            done <<< "$included_files"
        else
            echo "No included configuration files found."
            echo ""
        fi
    done

    echo "====================================================================================================="
    echo "Configuration display completed."
}

# 메인 함수 실행
main "$@"