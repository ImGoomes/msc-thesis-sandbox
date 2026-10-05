# Turtlesim

[turtlesim](https://docs.ros.org/en/lyrical/Tutorials/Beginner-CLI-Tools/Introducing-Turtlesim/Introducing-Turtlesim.html)
is a small 2D simulator for practicing basic ROS 2 ideas: nodes, topics, services
and parameters. Everything here runs inside the `ros-lyrical` Ubuntu container
described in [ros2-setup.md](ros2-setup.md).

## Install

Inside the container:

```bash
sudo apt update
sudo apt install -y ros-lyrical-turtlesim
```

Check it is available:

```bash
ros2 pkg executables turtlesim
# turtlesim draw_square
# turtlesim mimic
# turtlesim turtle_teleop_key
# turtlesim turtlesim_node
```

---

## Run it

Each terminal below is a new terminal on the Omarchy host.

**Terminal 1: the simulator**

```bash
distrobox enter ros-lyrical
ros2 run turtlesim turtlesim_node
```

A window with a turtle in the middle opens on the desktop.

**Terminal 2: keyboard control**

```bash
distrobox enter ros-lyrical
ros2 run turtlesim turtle_teleop_key
```

Keep this terminal focused and use the **arrow keys** to move the turtle.
`G B V C D E R T` rotate it to fixed angles, `F` cancels a rotation, and `Q` quits.

To stop either node, press `Ctrl+C` in its terminal.

---

## Inspect what is running

In a third terminal (`distrobox enter ros-lyrical` first):

```bash
ros2 node list                       # /turtlesim, /teleop_turtle
ros2 topic list                      # /turtle1/cmd_vel, /turtle1/pose, ...
ros2 topic echo /turtle1/pose        # live position of the turtle
ros2 topic info /turtle1/cmd_vel -v  # who publishes / subscribes
ros2 service list                    # /spawn, /clear, /reset, ...
ros2 param list /turtlesim           # background_r, background_g, background_b, ...
```

To see the graph of nodes and topics in a window:

```bash
rqt_graph
```

---

## Control it from the command line

Move in a circle by publishing velocity commands at 1 Hz:

```bash
ros2 topic pub --rate 1 /turtle1/cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 2.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 1.8}}"
```

Publish a single command and exit:

```bash
ros2 topic pub --once /turtle1/cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 2.0}, angular: {z: 0.0}}"
```

### Services

```bash
# Spawn a second turtle
ros2 service call /spawn turtlesim/srv/Spawn "{x: 2.0, y: 2.0, theta: 0.2, name: 'turtle2'}"

# Change the pen of turtle1 (color + width), or turn it off with off: 1
ros2 service call /turtle1/set_pen turtlesim/srv/SetPen "{r: 255, g: 0, b: 0, width: 3, 'off': 0}"

# Teleport turtle1
ros2 service call /turtle1/teleport_absolute turtlesim/srv/TeleportAbsolute "{x: 5.5, y: 5.5, theta: 0.0}"

# Erase the drawn trail / reset everything
ros2 service call /clear std_srvs/srv/Empty
ros2 service call /reset std_srvs/srv/Empty

# Remove a turtle
ros2 service call /kill turtlesim/srv/Kill "{name: 'turtle2'}"
```

To drive `turtle2` with the keyboard, remap the teleop topic:

```bash
ros2 run turtlesim turtle_teleop_key --ros-args --remap turtle1/cmd_vel:=turtle2/cmd_vel
```

### Parameters

```bash
ros2 param get /turtlesim background_g
ros2 param set /turtlesim background_r 150
ros2 service call /clear std_srvs/srv/Empty   # repaint the background
```

Start the node with a custom background:

```bash
ros2 run turtlesim turtlesim_node --ros-args -p background_r:=0 -p background_g:=0 -p background_b:=80
```

---

## Built-in demos

```bash
# Turtle drives in a square (run alongside turtlesim_node)
ros2 run turtlesim draw_square

# turtle2 copies turtle1's moves (spawn turtle2 first)
ros2 run turtlesim mimic --ros-args \
  --remap input/pose:=turtle1/pose --remap output/cmd_vel:=turtle2/cmd_vel
```

---

## Launch file

[launch/turtlesim_mimic.launch.py](../launch/turtlesim_mimic.launch.py) starts
several nodes with one command: two turtlesim windows (in namespaces `turtlesim1`
and `turtlesim2`) and a `mimic` node that makes turtle 2 copy turtle 1.

From the repo root, inside the container:

```bash
ros2 launch launch/turtlesim_mimic.launch.py
ros2 launch launch/turtlesim_mimic.launch.py background_b:=120   # launch argument
ros2 launch launch/turtlesim_mimic.launch.py --show-args         # list arguments
```

In a second terminal, drive turtle 1 and watch both move:

```bash
ros2 run turtlesim turtle_teleop_key --ros-args \
  --remap turtle1/cmd_vel:=/turtlesim1/turtle1/cmd_vel
```

`Ctrl+C` in the launch terminal stops all three nodes.

The same launch is also written in YAML in
[launch/turtlesim_mimic.launch.yaml](../launch/turtlesim_mimic.launch.yaml).
It takes the same arguments:

```bash
ros2 launch launch/turtlesim_mimic.launch.yaml background_b:=120
```

YAML (or XML) is shorter for plain "start these nodes with these settings"
launches. Python is needed when the launch has logic: conditions, loops,
computed values, or event handlers.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Package 'turtlesim' not found` | Run inside the container, and install `ros-lyrical-turtlesim`. |
| Window doesn't open / `could not connect to display` | On the host, run `xhost +si:localuser:$USER`. On Wayland, if it still fails, run `QT_QPA_PLATFORM=xcb ros2 run turtlesim turtlesim_node`. |
| Turtle doesn't move with the arrow keys | Click the **teleop terminal** so it has focus. Keystrokes in the turtlesim window do nothing. |
| Teleop runs but the turtle never moves | The nodes can't see each other. Check that both terminals have the same `ROS_DOMAIN_ID`, and turn off the VPN (see [ros2-setup.md](ros2-setup.md#troubleshooting)). |
| `distrobox enter` asks to create the container | Docker permissions, not turtlesim. See the `docker.sock` row in [ros2-setup.md](ros2-setup.md#troubleshooting). |
