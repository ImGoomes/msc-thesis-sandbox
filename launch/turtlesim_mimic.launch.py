"""Two turtlesim windows where turtle 2 copies every move of turtle 1.

Run inside the ros-lyrical container:

    ros2 launch launch/turtlesim_mimic.launch.py
    ros2 launch launch/turtlesim_mimic.launch.py background_b:=200

Then drive the first turtle from another terminal:

    ros2 run turtlesim turtle_teleop_key --ros-args --remap turtle1/cmd_vel:=/turtlesim1/turtle1/cmd_vel
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    background_b = LaunchConfiguration('background_b')

    return LaunchDescription([
        DeclareLaunchArgument(
            'background_b',
            default_value='255',
            description='Blue component (0-255) of both windows background',
        ),

        # Two simulators, kept apart by namespace so their topics don't clash:
        # /turtlesim1/turtle1/... and /turtlesim2/turtle1/...
        Node(
            package='turtlesim',
            executable='turtlesim_node',
            namespace='turtlesim1',
            name='sim',
            parameters=[{'background_b': background_b}],
        ),
        Node(
            package='turtlesim',
            executable='turtlesim_node',
            namespace='turtlesim2',
            name='sim',
            parameters=[{'background_b': background_b}],
        ),

        # Reads the pose of turtle 1 and publishes matching velocity
        # commands to turtle 2.
        Node(
            package='turtlesim',
            executable='mimic',
            name='mimic',
            remappings=[
                ('/input/pose', '/turtlesim1/turtle1/pose'),
                ('/output/cmd_vel', '/turtlesim2/turtle1/cmd_vel'),
            ],
        ),
    ])
