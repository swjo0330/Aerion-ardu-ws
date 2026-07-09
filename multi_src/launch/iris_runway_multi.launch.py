# 멀티 SITL 월드 launch — gz 서버 + GUI만 기동 (설계 정본 A6)
#
# 기체 스택(drone_multi.launch.py)은 포함하지 않는다 — 도메인별 ROS_DOMAIN_ID 환경 분리를 위해
# start_multi_sim.sh 가 인스턴스별로 별도 기동한다 (D3).
# RViz 는 자원 절약을 위해 기본 off (P-core 4 — F15). 필요 시 rviz:=true (domain 은 호출 셸이 결정).

import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.actions import IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch.substitutions import PathJoinSubstitution

from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    pkg_project_bringup = get_package_share_directory("ardupilot_gz_bringup")
    pkg_project_gazebo = get_package_share_directory("ardupilot_gz_gazebo")
    pkg_ros_gz_sim = get_package_share_directory("ros_gz_sim")

    gz_sim_server = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(pkg_ros_gz_sim, "launch", "gz_sim.launch.py")
        ),
        launch_arguments={
            "gz_args": "-v4 -s -r "
            + os.path.join(
                pkg_project_gazebo, "worlds", "iris_runway_multi.sdf"
            )
        }.items(),
    )

    gz_sim_gui = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(pkg_ros_gz_sim, "launch", "gz_sim.launch.py")
        ),
        launch_arguments={"gz_args": "-v4 -g"}.items(),
    )

    rviz = Node(
        package="rviz2",
        executable="rviz2",
        arguments=["-d", os.path.join(pkg_project_bringup, "rviz", "iris.rviz")],
        condition=IfCondition(LaunchConfiguration("rviz")),
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "rviz", default_value="false", description="Open RViz (기본 off — 자원 절약)."
            ),
            gz_sim_server,
            gz_sim_gui,
            rviz,
        ]
    )
