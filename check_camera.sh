#!/usr/bin/env bash
# /camera/image 전송 상태 진단
# Usage: bash check_camera.sh [remote_ip]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_IP="${1:-10.130.200.29}"

echo "============================================"
echo " /camera/image 전송 진단"
echo " 원격 IP: $REMOTE_IP"
echo "============================================"
echo ""

# 1. 시스템 설정
echo "=== 시스템 설정 ==="
echo "  maxfragsperpacket: $(sysctl -n net.inet.ip.maxfragsperpacket 2>/dev/null) (필요: ≥4096)"
echo "  udp.recvspace:     $(sysctl -n net.inet.udp.recvspace 2>/dev/null) (권장: ≥8388608)"
echo "  udp.maxdgram:      $(sysctl -n net.inet.udp.maxdgram 2>/dev/null) (권장: 65535)"
echo ""

# 2. 네트워크 인터페이스
echo "=== 네트워크 ==="
EN0_IP=$(ifconfig en0 2>/dev/null | grep "inet " | awk '{print $2}')
EN5_IP=$(ifconfig en5 2>/dev/null | grep "inet " | awk '{print $2}')
EN7_IP=$(ifconfig en7 2>/dev/null | grep "inet " | awk '{print $2}')
echo "  en0 (Wi-Fi): ${EN0_IP:-없음}"
echo "  en5 (유선):  ${EN5_IP:-없음}"
echo "  en7 (유선):  ${EN7_IP:-없음}"
echo "  ping $REMOTE_IP:"
PING_RESULT=$(ping -c 3 -t 3 "$REMOTE_IP" 2>&1 | tail -1)
echo "  $PING_RESULT"
echo ""

# 3. CYCLONEDDS_URI
echo "=== CycloneDDS 설정 ==="
PBPID=$(ps aux | grep parameter_bridge | grep -v grep | awk '{print $2}' | head -1)
if [ -n "$PBPID" ]; then
    echo "  parameter_bridge PID: $PBPID"
    RMW=$(ps eww "$PBPID" 2>/dev/null | tr ' ' '\n' | grep "RMW_IMPLEMENTATION" | head -1)
    URI=$(ps eww "$PBPID" 2>/dev/null | tr ' ' '\n' | grep "CYCLONEDDS_URI" | head -1)
    echo "  $RMW"
    echo "  $URI"
else
    echo "  parameter_bridge 미실행!"
fi
echo ""

# 4. 로컬 카메라 수신 테스트
echo "=== 로컬 /camera/image 수신 테스트 (5초) ==="
source "$HOME/anaconda3/etc/profile.d/conda.sh" 2>/dev/null
conda activate ros_env 2>/dev/null
source "${SCRIPT_DIR}/install/setup.bash" 2>/dev/null

python3 -c "
import rclpy, time
from sensor_msgs.msg import Image
rclpy.init()
node = rclpy.create_node('cam_diag')
n=[0]; sz=[0]
def cb(msg):
    n[0]+=1; sz[0]=len(msg.data)
    if n[0]==1: print(f'  첫 프레임: {msg.width}x{msg.height} {msg.encoding} ({len(msg.data)} bytes)')
node.create_subscription(Image,'/camera/image',cb,10)
t=time.time()
while time.time()-t<5: rclpy.spin_once(node,timeout_sec=0.5)
fps=n[0]/5.0
print(f'  {n[0]}프레임/5초 ({fps:.1f} fps), 프레임 크기: {sz[0]} bytes')
if n[0]==0: print('  ❌ 로컬 수신 실패 — parameter_bridge 확인 필요')
else: print(f'  ✅ 로컬 수신 정상, 초당 전송량: {sz[0]*fps/1024/1024:.1f} MB/s')
rclpy.shutdown()
" 2>&1
echo ""

# 5. 원격 전송 확인 (대형 UDP 패킷)
echo "=== 원격 전송 확인 (en5 → $REMOTE_IP, 3초) ==="
NIC=$(route get "$REMOTE_IP" 2>/dev/null | grep "interface" | awk '{print $2}')
if [ -z "$NIC" ]; then NIC="en0"; fi
COUNT=$(sudo timeout 3 tcpdump -i "$NIC" host "$REMOTE_IP" and udp and greater 1400 -n 2>&1 | grep -c "IP ")
if [ "$COUNT" -gt 0 ]; then
    echo "  ✅ 대형 UDP 패킷 ${COUNT}개 전송 중 (이미지 fragment)"
else
    echo "  ❌ 대형 패킷 없음 — 이미지 전송 안 됨"
fi
echo ""

# 6. UDP drop 통계
echo "=== UDP drop 통계 ==="
DROPS=$(netstat -s -p udp 2>/dev/null | grep "dropped due to full socket" | awk '{print $1}')
echo "  소켓 버퍼 오버플로우: ${DROPS:-0} 패킷"
echo ""

echo "============================================"
echo " 저쪽($REMOTE_IP)에서 안 받아지면 저쪽에서 확인:"
echo "  sudo sysctl -w net.ipv4.ipfrag_high_thresh=16777216"
echo "  sudo sysctl -w net.ipv4.ipfrag_max_dist=0"
echo "  sudo sysctl -w net.core.rmem_max=16777216"
echo "  sudo sysctl -w net.core.rmem_default=8388608"
echo "============================================"
