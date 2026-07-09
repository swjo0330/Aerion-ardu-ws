# 멀티 SITL 기체별 수직 스택 launch (설계 정본: Docs/specs/2026-07-09-multi-sitl-3instance-design.md A5)
#
# 인스턴스 i(0/1/2) 하나를 받아 SITL_i + micro_ros_agent_i + MAVProxy_i + bridge_i + rsp_i 를
# 포트 오프셋(+10i)·모델 사본(iris_d{i+1})·네임스페이스(/drone{i+1}) 로 조립한다.
#
# ⚠️ 도메인 분리는 이 파일이 아니라 호출자(start_multi_sim.sh)가 ROS_DOMAIN_ID=i+1 환경변수로 부여한다.
# ⚠️ eeprom 분리는 호출자가 인스턴스별 cwd(multi/i{i}/)에서 ros2 launch 를 실행해 달성한다 (F7).
#
# 사용:
#   cd multi/i0 && ROS_DOMAIN_ID=1 ros2 launch ardupilot_gz_bringup drone_multi.launch.py \
#       instance:=0 out:=10.130.200.29:14555

import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.actions import IncludeLaunchDescription
from launch.actions import OpaqueFunction
from launch.actions import RegisterEventHandler
from launch.event_handlers import OnProcessStart
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration

from launch_ros.actions import Node

# 기준 홈: 인천 활주로 (단일 모드와 동일).
# D9 최종 (2026-07-09 GPS 실측 확정): home GPS는 셋 다 **공유(base)**.
# ArduPilotPlugin이 gz 절대 위치를 SITL에 전달 → SITL navsat = home + gz_pos 이므로,
# gz 스폰만 북 30m·i(gen_multi_assets.sh SPAWN_NORTH_M=30) 주면 navsat이 정확히 30m 간격이 됨.
# ⚠️ home도 함께 오프셋하면 이중계산(60m)됨 — 실측으로 확인. home은 공유가 정답.
BASE_LAT = 37.39447652
BASE_LON = 126.6381927


def setup(context, *args, **kwargs):
    i = int(LaunchConfiguration("instance").perform(context))
    assert i in (0, 1, 2), f"instance must be 0/1/2, got {i}"
    n = i + 1                      # 도메인 번호 d = i+1 (D1)
    ns = f"drone{n}"               # ROS 네임스페이스 /drone{n}
    model_name = f"iris_with_gimbal_d{n}"  # 모델 사본 (A1 — fdm 9002+10i, 토픽 개명)

    out = LaunchConfiguration("out").perform(context)
    home = LaunchConfiguration("home").perform(context)
    if not home:
        home = f"{BASE_LAT},{BASE_LON},10,0"   # 공유 — gz 스폰 30m가 navsat 간격을 만듦 (이중계산 방지)

    pkg_ardupilot_sitl = get_package_share_directory("ardupilot_sitl")
    pkg_ardupilot_gazebo = get_package_share_directory("ardupilot_gazebo")
    pkg_project_bringup = get_package_share_directory("ardupilot_gz_bringup")

    # SITL + micro_ros_agent + MAVProxy (포트: --instance 가 SITL 기본 포트를 +10i,
    # agent(port)·master·sitl 은 여기서 명시 계산 — F1/F3)
    sitl_dds = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(pkg_ardupilot_sitl, "launch", "sitl_dds_udp.launch.py")
        ),
        launch_arguments={
            "transport": "udp4",
            "port": str(2019 + 10 * i),          # micro_ros_agent = DDS_UDP_PORT (parm과 짝)
            "synthetic_clock": "True",
            "wipe": "False",
            "model": "json",
            "speedup": "1",
            "slave": "0",
            "instance": str(i),                   # SITL 기본 포트 전부 +10i (F1)
            "sysid": str(n),                      # SYSID_THISMAV (F8)
            "defaults": os.path.join(
                pkg_ardupilot_gazebo, "config", "gazebo-iris-gimbal.parm"
            )
            + ","
            + os.path.join(
                pkg_ardupilot_sitl, "config", "default_params", f"dds_udp_d{n}.parm"
            ),
            "sim_address": "127.0.0.1",
            "master": f"tcp:127.0.0.1:{5760 + 10 * i}",
            "sitl": f"127.0.0.1:{5501 + 10 * i}",
            "out": out,
            "home": home,
        }.items(),
    )

    # sdformat_urdf 리소스 경로 (단일 iris.launch.py와 동일 처리)
    if "GZ_SIM_RESOURCE_PATH" in os.environ:
        gz_sim_resource_path = os.environ["GZ_SIM_RESOURCE_PATH"]
        if "SDF_PATH" in os.environ:
            os.environ["SDF_PATH"] = os.environ["SDF_PATH"] + ":" + gz_sim_resource_path
        else:
            os.environ["SDF_PATH"] = gz_sim_resource_path

    sdf_file = os.path.join(pkg_ardupilot_gazebo, "models", model_name, "model.sdf")
    with open(sdf_file, "r") as infp:
        robot_desc = infp.read()

    robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        name="robot_state_publisher",
        namespace=ns,
        output="both",
        parameters=[
            {"robot_description": robot_desc},
            {"frame_prefix": f"{ns}/"},   # TF 프레임 충돌 방지
        ],
    )

    bridge = Node(
        package="ros_gz_bridge",
        executable="parameter_bridge",
        namespace=ns,   # yaml의 상대 ros_topic_name 이 /drone{n}/... 로 네임스페이스됨
        parameters=[
            {
                "config_file": os.path.join(
                    pkg_project_bringup, "config", f"iris_bridge_d{n}.yaml"
                ),
                "qos_overrides./tf_static.publisher.durability": "transient_local",
            }
        ],
        output="screen",
    )

    topic_tools_tf = Node(
        package="topic_tools",
        executable="relay",
        namespace=ns,
        arguments=[f"/{ns}/gz/tf", f"/{ns}/tf"],
        output="screen",
        respawn=False,
    )

    return [
        sitl_dds,
        robot_state_publisher,
        bridge,
        RegisterEventHandler(
            OnProcessStart(target_action=bridge, on_start=[topic_tools_tf])
        ),
    ]


def generate_launch_description():
    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "instance", description="SITL instance 0/1/2 (domain=instance+1)"
            ),
            DeclareLaunchArgument(
                "out",
                default_value="127.0.0.1:14550",
                description="MAVProxy out 대상 [저쪽IP]:{14555+10i} — start_multi_sim.sh 가 주입",
            ),
            DeclareLaunchArgument(
                "home",
                default_value="",
                description="home lat,lon,alt,yaw — 비우면 공유 기준점 (GPS 간격은 gz 스폰 30m가 생성, 이중계산 방지)",
            ),
            OpaqueFunction(function=setup),
        ]
    )
