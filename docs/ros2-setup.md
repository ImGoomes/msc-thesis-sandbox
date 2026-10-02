# ROS 2 Lyrical Setup

This sandbox uses **ROS 2 Lyrical Luth**, running inside an **Ubuntu 26.04 container
managed by [distrobox](https://distrobox.it/)** on Omarchy.

Distrobox is not a VM: the container shares the host kernel, home directory, network,
display (Wayland/X11), GPU and USB devices. Code in `~/Work/...` is visible from both
the host and the container.

```
Omarchy (host)
└── docker
    └── distrobox container "ros-lyrical" (Ubuntu 26.04)
        └── /opt/ros/lyrical  (ros-lyrical-desktop + ros-dev-tools)
```

## What was done

### 1. Host (Omarchy)

```bash
# Install distrobox (docker was already installed)
sudo pacman -S distrobox

# Allow the user to talk to the docker daemon (log out/in afterwards)
sudo usermod -aG docker $USER

# Create the Ubuntu 26.04 container
distrobox create --name ros-lyrical --image ubuntu:26.04
```

### 2. Inside the container (`distrobox enter ros-lyrical`)

```bash
# Locale + universe repository
sudo apt update && sudo apt install -y locales software-properties-common curl
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
sudo add-apt-repository universe

# ROS 2 apt source
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb

# ROS 2 Lyrical (desktop variant) + build tools (colcon, rosdep, ...)
sudo apt update && sudo apt upgrade -y
sudo apt install -y ros-lyrical-desktop ros-dev-tools
```

### 3. Shell setup

`~/.zshrc` sources the ROS environment. The home directory is shared with the host,
and `/opt/ros` only exists inside the container, so the line is guarded:

```bash
[ -f /opt/ros/lyrical/setup.zsh ] && source /opt/ros/lyrical/setup.zsh
```

(If the container shell is bash, use `setup.bash` in `~/.bashrc` instead.)

---

## How to run

### Enter the ROS environment

```bash
distrobox enter ros-lyrical
```

Every terminal that needs ROS must run this first. You can check that ROS is loaded with:

```bash
echo $ROS_DISTRO   # -> lyrical
```

### Quick test: talker / listener

Terminal 1:
```bash
distrobox enter ros-lyrical
ros2 run demo_nodes_cpp talker
```

Terminal 2:
```bash
distrobox enter ros-lyrical
ros2 run demo_nodes_py listener
```

The listener should print `I heard: [Hello World: N]`.

### GUI tools

```bash
rviz2
rqt
```

Windows open directly on the Omarchy desktop.

### Useful commands

```bash
ros2 node list            # running nodes
ros2 topic list           # active topics
ros2 topic echo /chatter  # print messages on a topic
ros2 pkg list             # installed packages
ros2 doctor               # environment health check
```

---

## Creating a workspace

Run these inside the container:

```bash
mkdir -p ~/Work/my/msc-thesis-sandbox/ros2_ws/src
cd ~/Work/my/msc-thesis-sandbox/ros2_ws

# Create a package (Python or C++)
ros2 pkg create --build-type ament_python my_pkg --destination-directory src
# ros2 pkg create --build-type ament_cmake my_cpp_pkg --destination-directory src

# Install dependencies declared in package.xml files (run `sudo rosdep init` once first)
rosdep update
rosdep install --from-paths src -y --ignore-src

# Build
colcon build --symlink-install

# Load the workspace on top of the base ROS install
source install/setup.zsh
```

Add `build/`, `install/` and `log/` to `.gitignore`.

---

## Installing more ROS packages

Run inside the container:

```bash
sudo apt install ros-lyrical-<package-name>
# e.g. ros-lyrical-navigation2, ros-lyrical-ros-gz
```

---

## Container management (on the host)

```bash
distrobox list                 # list containers
distrobox stop ros-lyrical     # stop the container
distrobox enter ros-lyrical    # start + enter again
distrobox rm ros-lyrical       # delete the container (home directory files are kept)
```

To rebuild from scratch, remove the container and repeat the steps under [What was done](#what-was-done).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `permission denied ... /var/run/docker.sock` | User is not in the `docker` group, or the session hasn't picked it up. Run `sudo usermod -aG docker $USER`, then log out and back in (or `newgrp docker`). |
| `ros2: command not found` | You are on the host, not in the container (`distrobox enter ros-lyrical`), or the setup file isn't sourced. |
| `source: no such file or directory: /opt/ros/lyrical/setup.zsh` on the host | The line in `~/.zshrc` is missing the `[ -f ... ] &&` guard. |
| Nodes in different terminals can't see each other | Both terminals must use the same `ROS_DOMAIN_ID` (default `0`). A VPN (e.g. NordVPN) can interfere with DDS discovery; try disconnecting it. |
| GUI doesn't open | Run `xhost +si:localuser:$USER` on the host, then try again. |
