# ROS2 토픽 목록

SITL Mac (.35) + 원격 PC (.33) CycloneDDS 연결 시 확인된 토픽 (2026-04-09)

---

## SITL Mac (.35) 발행 토픽

### ArduPilot DDS (micro_ros_agent)

| 토픽 | 설명 |
|------|------|
| `/ap/airspeed` | 대기속도 |
| `/ap/battery` | 배터리 상태 |
| `/ap/clock` | ArduPilot 시계 |
| `/ap/cmd_gps_pose` | GPS 위치 명령 (구독) |
| `/ap/cmd_vel` | 속도 명령 (구독) |
| `/ap/geopose/filtered` | 필터링된 지오포즈 |
| `/ap/goal_lla` | 목표 위경도고도 (구독) |
| `/ap/gps_global_origin/filtered` | GPS 원점 |
| `/ap/imu/experimental/data` | IMU 데이터 |
| `/ap/joy` | 조이스틱 (구독) |
| `/ap/navsat` | GPS NavSat |
| `/ap/pose/filtered` | 필터링된 포즈 |
| `/ap/status` | 비행 상태 |
| `/ap/tf` | TF |
| `/ap/tf_static` | 정적 TF |
| `/ap/time` | 시간 |
| `/ap/twist/filtered` | 필터링된 속도 |

### ros_gz_bridge (Gazebo → ROS2)

| 토픽 | 메시지 타입 | 설명 |
|------|------------|------|
| `/camera/image` | `sensor_msgs/Image` | 짐벌 카메라 영상 |
| `/camera/camera_info` | `sensor_msgs/CameraInfo` | 카메라 파라미터 |
| `/imu` | `sensor_msgs/Imu` | IMU 센서 |
| `/navsat` | `sensor_msgs/NavSatFix` | GPS |
| `/odometry` | `nav_msgs/Odometry` | 오도메트리 |
| `/air_pressure` | `sensor_msgs/FluidPressure` | 기압 |
| `/magnetometer` | `sensor_msgs/MagneticField` | 지자기 |
| `/battery` | `sensor_msgs/BatteryState` | 배터리 |
| `/clock` | `rosgraph_msgs/Clock` | 시뮬레이션 시계 |
| `/joint_states` | `sensor_msgs/JointState` | 관절 상태 |
| `/gz/tf` | `tf2_msgs/TFMessage` | Gazebo TF |
| `/gz/tf_static` | `tf2_msgs/TFMessage` | Gazebo 정적 TF |

### 기타 (robot_state_publisher, relay, rviz2)

| 토픽 | 설명 |
|------|------|
| `/robot_description` | URDF 모델 |
| `/tf` | ROS TF 트리 (relay: /gz/tf → /tf) |
| `/tf_static` | 정적 TF |

---

## 원격 PC (.33) 발행 토픽

### MAVROS

| 토픽 | 설명 |
|------|------|
| `/mavros/state` | FCU 연결/모드 상태 |
| `/mavros/battery` | 배터리 |
| `/mavros/imu/data` | IMU |
| `/mavros/imu/data_raw` | 원시 IMU |
| `/mavros/imu/mag` | 지자기 |
| `/mavros/global_position/global` | 글로벌 위치 |
| `/mavros/global_position/local` | 로컬 위치 |
| `/mavros/global_position/rel_alt` | 상대 고도 |
| `/mavros/global_position/compass_hdg` | 나침반 방향 |
| `/mavros/local_position/pose` | 로컬 포즈 |
| `/mavros/local_position/odom` | 로컬 오도메트리 |
| `/mavros/local_position/velocity_body` | 몸체 속도 |
| `/mavros/local_position/velocity_local` | 로컬 속도 |
| `/mavros/vfr_hud` | VFR HUD |
| `/mavros/extended_state` | 확장 상태 |
| `/mavros/home_position/home` | 홈 위치 |
| `/mavros/rc/in` | RC 입력 |
| `/mavros/rc/out` | RC 출력 |
| `/mavros/mission/waypoints` | 웨이포인트 |
| `/mavros/setpoint_position/local` | 위치 명령 (구독) |
| `/mavros/setpoint_velocity/cmd_vel` | 속도 명령 (구독) |
| `/diagnostics` | ROS 진단 |

> 전체 `/mavros/*` 토픽은 하단 전체 목록 참고

### 에이전트/비전

| 토픽 | 설명 |
|------|------|
| `/a2a/drone1/decision` | A2A 에이전트 의사결정 |
| `/a2a/drone1/mission_command` | A2A 미션 명령 |
| `/vision/detect_frame` | 비전 감지 프레임 |
| `/vision/detect_information` | 비전 감지 정보 |
| `/vision/detect_target` | 비전 감지 타겟 |
| `/vision/target_data` | 타겟 데이터 |
| `/perception/state` | 인식 상태 |
| `/replan_waypoints` | 경로 재계획 |

---

## 전체 토픽 리스트

<details>
<summary>펼치기 (157개)</summary>

```
/a2a/drone1/decision
/a2a/drone1/mission_command
/air_pressure
/ap/airspeed
/ap/battery
/ap/clock
/ap/cmd_gps_pose
/ap/cmd_vel
/ap/geopose/filtered
/ap/goal_lla
/ap/gps_global_origin/filtered
/ap/imu/experimental/data
/ap/joy
/ap/navsat
/ap/pose/filtered
/ap/status
/ap/tf
/ap/tf_static
/ap/time
/ap/twist/filtered
/battery
/camera/camera_info
/camera/image
/clicked_point
/clock
/diagnostics
/goal_pose
/gz/tf
/gz/tf_static
/imu
/initialpose
/joint_states
/magnetometer
/mavros/adsb/send
/mavros/adsb/vehicle
/mavros/battery
/mavros/cam_imu_sync/cam_imu_stamp
/mavros/camera/image_captured
/mavros/cellular_status/status
/mavros/companion_process/status
/mavros/esc_status/info
/mavros/esc_status/status
/mavros/esc_telemetry/telemetry
/mavros/estimator_status
/mavros/extended_state
/mavros/fake_gps/mocap/pose
/mavros/geofence/fences
/mavros/gimbal_control/device/attitude_status
/mavros/gimbal_control/device/info
/mavros/gimbal_control/device/set_attitude
/mavros/gimbal_control/manager/info
/mavros/gimbal_control/manager/set_attitude
/mavros/gimbal_control/manager/set_manual_control
/mavros/gimbal_control/manager/set_pitchyaw
/mavros/gimbal_control/manager/status
/mavros/global_position/compass_hdg
/mavros/global_position/global
/mavros/global_position/gp_lp_offset
/mavros/global_position/gp_origin
/mavros/global_position/local
/mavros/global_position/raw/fix
/mavros/global_position/raw/gps_vel
/mavros/global_position/raw/satellites
/mavros/global_position/rel_alt
/mavros/global_position/set_gp_origin
/mavros/gps_input/gps_input
/mavros/gps_rtk/rtk_baseline
/mavros/gps_rtk/send_rtcm
/mavros/gpsstatus/gps1/raw
/mavros/gpsstatus/gps1/rtk
/mavros/gpsstatus/gps2/raw
/mavros/gpsstatus/gps2/rtk
/mavros/home_position/home
/mavros/home_position/set
/mavros/imu/data
/mavros/imu/data_raw
/mavros/imu/diff_pressure
/mavros/imu/mag
/mavros/imu/static_pressure
/mavros/imu/temperature_baro
/mavros/imu/temperature_imu
/mavros/landing_target/lt_marker
/mavros/landing_target/pose
/mavros/landing_target/pose_in
/mavros/local_position/accel
/mavros/local_position/odom
/mavros/local_position/pose
/mavros/local_position/pose_cov
/mavros/local_position/velocity_body
/mavros/local_position/velocity_body_cov
/mavros/local_position/velocity_local
/mavros/log_transfer/raw/log_data
/mavros/log_transfer/raw/log_entry
/mavros/mag_calibration/report
/mavros/mag_calibration/status
/mavros/manual_control/control
/mavros/manual_control/send
/mavros/mission/reached
/mavros/mission/waypoints
/mavros/mocap/pose
/mavros/mocap/tf
/mavros/mount_control/command
/mavros/mount_control/orientation
/mavros/mount_control/status
/mavros/nav_controller_output/output
/mavros/obstacle/send
/mavros/odometry/in
/mavros/odometry/out
/mavros/onboard_computer/status
/mavros/optical_flow/ground_distance
/mavros/optical_flow/raw/optical_flow
/mavros/optical_flow/raw/send
/mavros/param/event
/mavros/play_tune
/mavros/radio_status
/mavros/rallypoint/rallypoints
/mavros/rangefinder/rangefinder
/mavros/rangefinder_pub
/mavros/rangefinder_sub
/mavros/rc/in
/mavros/rc/out
/mavros/rc/override
/mavros/setpoint_accel/accel
/mavros/setpoint_attitude/cmd_vel
/mavros/setpoint_attitude/thrust
/mavros/setpoint_position/global
/mavros/setpoint_position/global_to_local
/mavros/setpoint_position/local
/mavros/setpoint_raw/attitude
/mavros/setpoint_raw/global
/mavros/setpoint_raw/local
/mavros/setpoint_raw/target_attitude
/mavros/setpoint_raw/target_global
/mavros/setpoint_raw/target_local
/mavros/setpoint_trajectory/desired
/mavros/setpoint_trajectory/local
/mavros/setpoint_velocity/cmd_vel
/mavros/setpoint_velocity/cmd_vel_unstamped
/mavros/state
/mavros/status_event
/mavros/statustext/recv
/mavros/statustext/send
/mavros/sys_status
/mavros/terrain/report
/mavros/time_reference
/mavros/timesync_status
/mavros/trajectory/desired
/mavros/trajectory/generated
/mavros/trajectory/path
/mavros/tunnel/in
/mavros/tunnel/out
/mavros/vfr_hud
/mavros/vision_pose/pose
/mavros/vision_pose/pose_cov
/mavros/vision_speed/speed_twist
/mavros/vision_speed/speed_twist_cov
/mavros/vision_speed/speed_vector
/mavros/wind_estimation
/move_base_simple/goal
/navsat
/odometry
/parameter_events
/perception/state
/replan_waypoints
/robot_description
/rosout
/tf
/tf_static
/uas1/mavlink_sink
/uas1/mavlink_source
/vision/detect_frame
/vision/detect_information
/vision/detect_target
/vision/target_data
```

</details>
