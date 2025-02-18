#!/bin/bash

RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;96m'
WHITE='\033[0;37m'
RESET='\033[0m'
yellow() {
  echo -e "${YELLOW}$1${RESET}"
}
green() {
  echo -e "${GREEN}$1${RESET}"
}
red() {
  echo -e "${RED}$1${RESET}"
}
installpath="$HOME"
USER="$(whoami)"
if [[ -e "$installpath/serv00-play" ]]; then
  source ${installpath}/serv00-play/utils.sh
fi



killUserProc() {
  local user=$(whoami)
  pkill -kill -u $user
}


setCnTimeZone() {
  read -p "确定设置中国上海时区? [y/n] [y]:" input
  input=${input:-y}

  cd ${installpath}
  if [ "$input" = "y" ]; then
    devil binexec on
    touch .profile
    cat .profile | perl ./serv00-play/mkprofile.pl >tmp_profile
    mv -f tmp_profile .profile

    read -p "$(yellow 设置完毕,需要重新登录才能生效，是否重新登录？[y/n] [y]:)" input
    input=${input:-y}

    if [ "$input" = "y" ]; then
      kill -9 $PPID
    fi
  fi

}


showIP() {
  myip="$(curl -s icanhazip.com)"
  green "本机IP: $myip"
}

uninstallMtg() {
  read -p "确定卸载? [y/n] [n]:" input
  input=${input:-n}

  if [[ "$input" == "n" ]]; then
    return 1
  fi

  if [[ -e "mtg" ]]; then
    if checkProcAlive mtg; then
      stopMtg
    fi
    cd ${installpath}/serv00-play
    rm -rf dmtg
    green "卸载完毕！"
  fi
}

installMtg() {
  if [ ! -e "mtg" ]; then
    # read -p "请输入使用密码:" password
    if ! checkDownload "mtg"; then
      return 1
    fi
  fi

  chmod +x ./mtg
  if [ -e "config.json" ]; then
    echo "已存在配置如下:"
    cat config.json
    read -p "是否重新生成配置? [y/n] [n]:" input
    input=${input:-n}
    if [ "$input" == "n" ]; then
      return 0
    fi
  fi

  #自动生成密钥
  head=$(hostname | cut -d '.' -f 1)
  no=${head#s}
  host="panel${no}.serv00.com"
  secret=$(./mtg generate-secret --hex $host)
  loadPort
  randomPort tcp mtg
  if [[ -n "$port" ]]; then
    mtpport="$port"
  fi

  cat >config.json <<EOF
   {
      "secret": "$secret",
      "port": "$mtpport"
   }
EOF
  yellow "安装完成!"
}

startMtg() {
  cd ${installpath}/serv00-play

  if [ ! -e "dmtg" ]; then
    ehco "未安装mtproto，请先行安装配置!"
    return 1
  fi
  cd dmtg
  config="config.json"
  if [ ! -e $config ]; then
    red "未安装mtproto，请先行安装配置!"
    return 1
  fi

  if checkMtgAlive; then
    echo "已在运行,请勿重复启动"
    return 0
  fi

  read -p "是否需要日志？: [y/n] [n]:" input
  input=${input:-n}

  if [ "$input" == "y" ]; then
    green "日志文件名称为:mtg.log"
    logfile="-d >mtg.log"
  else
    logfile=" >/dev/null "
  fi

  host="$(hostname | cut -d '.' -f 1)"

  secret=$(jq -r ".secret" $config)
  port=$(jq -r ".port" $config)

  cmd="nohup ./mtg simple-run -n 1.1.1.1 -t 30s -a 1MB 0.0.0.0:${port} ${secret} -c 8192 --prefer-ip=\"prefer-ipv6\" ${logfile} 2>&1 &"
  eval "$cmd"
  sleep 3
  if checkMtgAlive; then
    mtproto="https://t.me/proxy?server=${host}.serv00.com&port=${port}&secret=${secret}"
    echo "$mtproto"
    green "启动成功"
  else
    echo "启动失败，请检查进程"
  fi

}

stopMtg() {
  r=$(ps aux | grep mtg | grep -v "grep" | awk '{print $2}')
  if [ -z "$r" ]; then
    echo "没有运行!"
    return
  else
    kill -9 $r
  fi
  echo "已停掉mtproto!"

}

mtprotoServ() {
  if ! checkInstalled "serv00-play"; then
    return 1
  fi
  cd ${installpath}/serv00-play

  if [ ! -e "dmtg" ]; then
    mkdir -p dmtg
  fi
  cd dmtg

  while true; do
    yellow "---------------------"
    echo "服务状态: $(checkProcStatus mtg)"
    echo "mtproto管理:"
    echo "1. 安装"
    echo "2. 启动"
    echo "3. 停止"
    echo "4. 卸载"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    yellow "---------------------"
    read -p "请选择:" input

    case $input in
    1)
      installMtg
      ;;
    2)
      startMtg
      ;;
    3)
      stopMtg
      ;;
    4)
      uninstallMtg
      ;;
    9)
      break
      ;;
    0)
      exit 0
      ;;
    *)
      echo "无效选项，请重试"
      ;;
    esac
  done
  showMenu

}



update_http_port() {
  cd data || return 1
  local port=$1
  local config_file="config.json"

  if [ -z "$port" ]; then
    echo "Error: No port number provided."
    return 1
  fi
  # 使用 jq 来更新配置文件中的 http_port
  jq --argjson new_port "$port" '.scheme.http_port = $new_port' "$config_file" >tmp.$$.json && mv tmp.$$.json "$config_file"

  echo "配置文件处理完毕."

}




declare -a indexPorts
loadIndexPorts() {
  output=$(devil port list)

  indexPorts=()
  # 解析输出内容
  index=0
  while read -r port typ opis; do
    # 跳过标题行
    if [[ "$port" =~ "Port" ]]; then
      continue
    fi
    #echo "port:$port,typ:$typ, opis:$opis"
    if [[ "$port" =~ "Brak" || "$port" =~ "No" ]]; then
      echo "未分配端口"
      return 0
    fi

    if [[ -n "$port" ]]; then
      opis=${opis:-""}
      indexPorts[$index]="$port|$typ|$opis"
      ((index++))
    fi
  done <<<"$output"

}

printIndexPorts() {
  local i=1
  echo "  Port   | Type  |  Description"
  for entry in "${indexPorts[@]}"; do
    # 使用 | 作为分隔符拆分 port、typ 和 opis

    IFS='|' read -r port typ opis <<<"$entry"
    echo "${i}. $port |  $typ | $opis"
    ((i++))
  done
}

delPortMenu() {
  loadIndexPorts

  if [[ ${#indexPorts[@]} -gt 0 ]]; then
    printIndexPorts
    read -p "请选择要删除的端口记录编号(输入-1删除所有端口记录, 回车返回):" number
    number=${number:-99}

    if [[ $number -eq 99 ]]; then
      return
    elif [[ $number -gt 3 || $number -lt -1 || $number -eq 0 ]]; then
      echo "非法输入!"
      return
    elif [[ $number -eq -1 ]]; then
      cleanPort
    else
      idx=$((number - 1))
      IFS='|' read -r port typ opis <<<${indexPorts[$idx]}
      devil port del $typ $port >/dev/null 2>&1
    fi
    echo "删除完毕!"
  else
    red "未有分配任何端口!"
  fi

}

addPortMenu() {
  echo "选择端口类型:"
  echo "1. tcp"
  echo "2. udp"
  read -p "请选择:" co

  if [[ "$co" != "1" && "$co" != "2" ]]; then
    red "非法输入"
    return
  fi
  local type=""
  if [[ "$co" == "1" ]]; then
    type="tcp"
  else
    type="udp"
  fi
  loadPort
  read -p "请输入端口备注(如hy2，vmess，用于脚本自动获取端口):" opts
  read -p "是否自动分配端口? [y/n] [y]:" input
  input=${input:-y}
  if [[ "$input" == "y" ]]; then
    port=$(getPort $type $opts)
    if [[ "$port" == "failed" ]]; then
      red "分配端口失败,请重新操作!"
    else
      green "分配出来的端口是:$port"
    fi
  else
    read -p "请输入端口号:" port
    if [[ -z "$port" ]]; then
      red "端口不能为空"
      return 1
    fi
    resp=$(devil port add $type $port $opts)
    if [[ "$resp" =~ .*succesfully.*$ || "$resp" =~ .*Ok.*$ ]]; then
      green "添加端口成功!"
    else
      red "添加端口失败!"
    fi
  fi

}

portServ() {
  while true; do
    yellow "----------------------"
    echo "端口管理:"
    echo "1. 删除某条端口记录"
    echo "2. 增加一条端口记录"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    yellow "----------------------"
    read -p "请选择:" input
    case $input in
    1)
      delPortMenu
      ;;
    2)
      addPortMenu
      ;;
    9)
      break
      ;;
    0)
      exit 0
      ;;
    *)
      echo "无效选项，请重试"
      ;;
    esac
  done
  showMenu
}


get_default_webip() {
  local host="$(hostname | cut -d '.' -f 1)"
  local sno=${host/s/web}
  local webIp=$(devil vhost list public | grep "$sno" | awk '{print $1}')
  echo "$webIp"
}

applyLE() {
  local domain=$1
  local webIp=$2
  workpath="${installpath}/serv00-play/ssl"
  cd "$workpath"

  if [[ -z "$domain" ]]; then
    read -p "请输入待申请证书的域名:" domain
    domain=${domain:-""}
    if [[ -z "$domain" ]]; then
      red "域名不能为空"
      return 1
    fi
  fi
  inCron="0"
  if crontab -l | grep -F "$domain" >/dev/null 2>&1; then
    inCron="1"
    echo "该域名已配置定时申请证书，是否删除定时配置记录，改为手动申请？[y/n] [n]:" input
    input=${input:-n}

    if [[ "$input" == "y" ]]; then
      crontab -l | grep -v "$domain" | crontab -
    fi
  fi
  if [[ -z "$webIp" ]]; then
    read -p "是否指定webip? [y/n] [n]:" input
    input=${input:-n}
    if [[ "$input" == "y" ]]; then
      read -p "请输入webip:" webIp
      if [[ -z "webIp" ]]; then
        red "webip 不能为空!!!"
        return 1
      fi
    else
      host="$(hostname | cut -d '.' -f 1)"
      sno=${host/s/web}
      webIp=$(devil vhost list public | grep "$sno" | awk '{print $1}')
    fi
  fi
  #echo "申请证书时，webip是: $webIp"
  resp=$(devil ssl www add $webIp le le $domain)
  if [[ ! "$resp" =~ .*succesfully.*$ ]]; then
    red "申请ssl证书失败！$resp"
    if [[ "$inCron" == "0" ]]; then
      read -p "是否配置定时任务自动申请SSL证书？ [y/n] [n]:" input
      input=${input:-n}
      if [[ "$input" == "y" ]]; then
        cronLE
      fi
    fi
  else
    green "证书申请成功!"
  fi
}

selfSSL() {
  workpath="${installpath}/serv00-play/ssl"
  cd "$workpath"

  read -p "请输入待申请证书的域名:" self_domain
  self_domain=${self_domain:-""}
  if [[ -z "$self_domain" ]]; then
    red "域名不能为空"
    return 1
  fi

  echo "正在生成证书..."

  cat >openssl.cnf <<EOF
    [req]
    distinguished_name = req_distinguished_name
    req_extensions = req_ext
    x509_extensions = v3_ca # For self-signed certs
    prompt = no

    [req_distinguished_name]
    C = US
    ST = ca
    L = ca
    O = ca
    OU = ca
    CN = $self_domain

    [req_ext]
    subjectAltName = @alt_names

    [v3_ca]
    subjectAltName = @alt_names

    [alt_names]
    DNS.1 = $self_domain

EOF
  openssl req -new -newkey rsa:2048 -nodes -keyout _private.key -x509 -days 3650 -out _cert.crt -config openssl.cnf -extensions v3_ca >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "生成证书失败!"
    return 1
  fi

  echo "已生成证书:"
  green "_private.key"
  green "_cert.crt"

  echo "正在导入证书.."
  host="$(hostname | cut -d '.' -f 1)"
  sno=${host/s/web}
  webIp=$(devil vhost list public | grep "$sno" | awk '{print $1}')
  resp=$(devil ssl www add "$webIp" ./_cert.crt ./_private.key "$self_domain")

  if [[ ! "$resp" =~ .*succesfully.*$ ]]; then
    echo "导入证书失败:$resp"
    return 1
  fi

  echo "导入成功！"

}


showIPStatus() {
  yellow "----------------------------------------------"
  green "  主机名称          |      IP        |  状态"
  yellow "----------------------------------------------"

  show_ip_status
}

makeWWW() {
  local proc=$1
  local port=$2
  local www_type=${3:-"proxy"}

  echo "正在处理服务IP,请等待..."
  is_self_domain=0
  webIp=$(get_webip)
  default_webip=$(get_default_webip)
  green "可用webip是: $webIp, 默认webip是: $default_webip"
  read -p "是否使用自定义域名? [y/n] [n]:" input
  input=${input:-n}
  if [[ "$input" == "y" ]]; then
    is_self_domain=1
    read -p "请输入域名(确保此前域名已指向webip):" domain
  else
    user="$(whoami)"
    if isServ00; then
      domain="${proc}.$user.serv00.net"
    else
      domain="$proc.$user.ct8.pl"
    fi
  fi

  if [[ -z "$domain" ]]; then
    red "输入无效域名!"
    return 1
  fi

  domain=${domain,,}
  echo "正在绑定域名,请等待..."
  if [[ "$www_type" == "proxy" ]]; then
    resp=$(devil www add $domain proxy localhost $port)
  else
    resp=$(devil www add $domain php)
  fi
  #echo "resp:$resp"
  if [[ ! "$resp" =~ .*succesfully.*$ && ! "$resp" =~ .*Ok.*$ ]]; then
    if [[ ! "$resp" =~ "This domain already exists" ]]; then
      red "申请域名$domain 失败！"
      return 1
    fi
  fi

  # 自定义域名的特殊处理
  if [[ $is_self_domain -eq 1 ]]; then
    host="$(hostname | cut -d '.' -f 1)"
    sno=${host/s/web}
    default_webIp=$(devil vhost list public | grep "$sno" | awk '{print $1}')
    rid=$(devil dns list "$domain" | grep "$default_webIp" | awk '{print $1}')
    resp=$(echo "y" | devil dns del "$domain" $rid)
    #echo "resp:$resp"
  else
    webIp=$(get_default_webip)
  fi
  # 保存信息
  if [[ "$www_type" == "proxy" ]]; then
    cat >config.json <<EOF
  {
     "webip": "$webIp",
     "domain": "$domain",
     "port": "$port"
  }
EOF
  fi

  green "域名绑定成功,你的域名是:$domain"
  green "你的webip是:$webIp"
}



nonServ() {
  cat <<EOF
   占坑位，未开发功能，敬请期待！
   如果你知道有好的项目，可以到我的频道进行留言投稿，
   我会分析可行性，择优取录，所以你喜欢的项目有可能会集成到serv00-play的项目中。
   留言板：https://t.me/fanyou_channel/40
EOF
}

checkInstalled() {
  local model=$1
  if [[ "$model" == "serv00-play" ]]; then
    if [[ ! -d "${installpath}/$model" ]]; then
      red "请先安装$model !!!"
      return 1
    else
      return 0
    fi
  else
    if [[ ! -d "${installpath}/serv00-play/$model" ]]; then
      red "请先安装$model !!!"
      return 1
    else
      return 0
    fi
  fi
  return 1
}


showMenu() {
  art_wrod=$(figlet "serv00-play")
  echo "<------------------------------------------------------------------>"
  echo -e "${CYAN}${art_wrod}${RESET}"
  echo -e "${GREEN} 饭奇骏频道:https://www.youtube.com/@frankiejun8965 ${RESET}"
  echo -e "${GREEN} TG交流群:https://t.me/fanyousuiqun ${RESET}"
  echo -e "${GREEN} 当前版本号:$(getCurrentVer) 最新版本号:$(getLatestVer) ${RESET}"
  echo "<------------------------------------------------------------------>"
  echo "请选择一个选项:"

  options=("安装/更新serv00-play项目" "sun-panel" "webssh" "阅后即焚" "linkalive" "设置保活的项目" "配置sing-box"
    "运行sing-box" "停止sing-box" "显示sing-box节点信息" "快照恢复" "系统初始化" "前置工作及设置中国时区" "管理哪吒探针" "卸载探针" "设置彩色开机字样" "显示本机IP"
    "mtproto代理" "alist管理" "端口管理" "域名证书管理" "一键root" "自动检测主机IP状态" "一键更换hy2的IP" "卸载")

  select opt in "${options[@]}"; do
    case $REPLY in
    1)
      install
      ;;
    6)
      setConfig
      ;;
    7)
      configSingBox
      ;;
    13)
      setCnTimeZone
      ;;
    17)
      showIP
      ;;
    18)
      mtprotoServ
      ;;
    20)
      portServ
      ;;
    25)
      uninstall
      ;;
    0)
      echo "退出"
      exit 0
      ;;
    *)
      echo "无效的选项 "
      ;;
    esac

  done

}

showMenu
