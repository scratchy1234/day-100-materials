#!/bin/bash
# better-ccflare 最终精简管理脚本
# 保存为 ~/bin/ccflare.sh 并 chmod +x ~/bin/ccflare.sh
# 用法: ccflare.sh start|stop|restart|status

B="$HOME/bin/better-ccflare"
L="$HOME/.config/better-ccflare/ccflare.log"
P="$HOME/.config/better-ccflare/ccflare.pid"

mkdir -p ~/.config/better-ccflare

[ ! -x "$B" ] && echo "❌ 请先执行：mkdir -p ~/bin && mv ~/better-ccflare-macos-arm64 ~/bin/better-ccflare && chmod +x ~/bin/better-ccflare" && exit 1

is_running() { [ -f "$P" ] && kill -0 "$(cat "$P")" 2>/dev/null; }

case "$1" in
  start)
    if is_running; then
      echo "✅ 已在运行 (PID: $(cat "$P")) → http://127.0.0.1:8080/dashboard"
      exit 0
    fi
    rm -f "$P"
    BETTER_CCFLARE_HOST=127.0.0.1 nohup "$B" >> "$L" 2>&1 &
    echo $! > "$P"
    sleep 1
    if is_running; then
      echo "🚀 已启动 (PID: $(cat "$P"))"
      echo "   Dashboard: http://127.0.0.1:8080/dashboard"
      echo "   日志: $L"
    else
      echo "❌ 启动失败，请检查日志：$L"
      rm -f "$P"
      exit 1
    fi
    ;;
  stop)
    if is_running; then
      kill "$(cat "$P")" && rm -f "$P"
      echo "🛑 已停止"
    else
      echo "ℹ️ 未在运行"
    fi
    ;;
  restart)
    $0 stop && sleep 1 && $0 start
    ;;
  status)
    if is_running; then
      echo "✅ 运行中 (PID: $(cat "$P"))"
      echo "   Dashboard: http://127.0.0.1:8080/dashboard"
    else
      echo "⛔ 未运行"
    fi
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status}"
    ;;
esac
