#!/bin/bash
clear
echo "==================================================================="
echo "==================================================================="
echo "  "
echo "  "
echo "  "
echo "==================================================================="
echo "==================================================================="
mtproxy_script="https://raw.githubusercontent.com/Y560H/serv00-mtp/refs/heads/main/mtp.sh"
select option in \
    "安装 serv00 MTproxy" \
    "退出"
do
    case $option in
       
        "安装 serv00 MTproxy")
            echo "开始安装 MTproxy..."
            bash <(curl -Ls "$mtproxy_script") || echo "Error: Failed to execute script."
            ;;
        "exit")
            echo "Exiting the program"
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
