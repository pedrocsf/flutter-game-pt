import math

TAU = 2.0 * math.pi
SIDES = ("R", "L")
CHANNEL_DEFAULTS = {"root.scale": 1.0, "root.pivot": 0.9}


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smoothstep(value):
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def blend(first, second, weight):
    channels = {}
    for key in set(first) | set(second):
        default = CHANNEL_DEFAULTS.get(key, 0.0)
        start = first.get(key, default)
        end = second.get(key, default)
        channels[key] = start + (end - start) * weight
    return channels


def interpolate(keys, frame):
    if frame <= keys[0][0]:
        return dict(keys[0][1])
    for (start_frame, start), (end_frame, end) in zip(keys, keys[1:]):
        if start_frame <= frame <= end_frame:
            return blend(start, end, smoothstep((frame - start_frame) / (end_frame - start_frame)))
    return dict(keys[-1][1])


def plant(channels, side, foot_pitch=0.0):
    body_pitch = channels.get("root.pitch", 0.0) + channels.get("pelvis.pitch", 0.0)
    swing = channels.get(f"hip_{side}.swing", 0.0)
    knee = channels.get(f"knee_{side}.bend", 0.0)
    channels[f"ankle_{side}.bend"] = body_pitch - swing + knee - foot_pitch
    return channels


def leg(channels, side, swing, knee, foot_pitch=0.0, spread=0.0):
    channels[f"hip_{side}.swing"] = swing
    channels[f"hip_{side}.spread"] = spread
    channels[f"knee_{side}.bend"] = knee
    return plant(channels, side, foot_pitch)


def arm(channels, side, swing, elbow, spread=0.0, wrist=0.0):
    channels[f"shoulder_{side}.swing"] = swing
    channels[f"shoulder_{side}.spread"] = spread
    channels[f"elbow_{side}.bend"] = elbow
    channels[f"wrist_{side}.bend"] = wrist
    return channels


def pose(channels, ground="feet"):
    return {"channels": channels, "ground": ground}


def idle(frame, count):
    phase = TAU * frame / count
    breath = math.sin(phase)
    sway = math.sin(phase - 0.7)
    channels = {
        "spine.pitch": 3.0 - 1.2 * breath,
        "spine.stretch": 0.012 * breath,
        "neck.pitch": 2.0,
        "head.pitch": -3.0 + 1.6 * sway,
        "pelvis.yaw": -4.0,
        "spine.yaw": 2.0,
    }
    arm(channels, "R", 6.0 + 2.5 * sway, 14.0 + 3.0 * sway, 3.0 + 1.0 * breath, 6.0)
    arm(channels, "L", -4.0 + 2.5 * sway, 12.0 + 3.0 * sway, 3.0 + 1.0 * breath, 6.0)
    leg(channels, "R", 7.0, 5.0)
    leg(channels, "L", -6.0, 6.0)
    return pose(channels)


def run(frame, count):
    phase = TAU * frame / count
    channels = {
        "spine.pitch": 13.0 + 2.0 * math.cos(2.0 * phase),
        "neck.pitch": -4.0,
        "head.pitch": -9.0 + 2.0 * math.cos(2.0 * phase),
        "pelvis.yaw": 8.0 * math.sin(phase),
        "spine.yaw": -14.0 * math.sin(phase),
        "head.yaw": 6.0 * math.sin(phase),
        "root.lift": 0.03 * (0.5 + 0.5 * math.cos(2.0 * (phase - 0.35))),
    }
    for side, offset in zip(SIDES, (0.0, math.pi)):
        local = phase + offset
        swing = 8.0 + 42.0 * math.sin(local)
        knee = 14.0 + 95.0 * ((1.0 + math.cos(local + 0.5)) / 2.0) ** 1.6
        foot = 12.0 + 22.0 * math.cos(local + 0.3)
        leg(channels, side, swing, knee, foot)
        arm(channels, side, 6.0 - 46.0 * math.sin(local), 88.0 - 14.0 * math.sin(local), 6.0, 10.0)
    return pose(channels)


def stand():
    return idle(0, 18)["channels"]


def crouch_pose():
    channels = {"spine.pitch": 24.0, "neck.pitch": -6.0, "head.pitch": -12.0, "pelvis.pitch": 6.0}
    arm(channels, "R", -40.0, 25.0, 10.0, 10.0)
    arm(channels, "L", -46.0, 25.0, 10.0, 10.0)
    leg(channels, "R", 55.0, 90.0)
    leg(channels, "L", 48.0, 85.0)
    return channels


def launch_pose():
    channels = {"spine.pitch": 6.0, "head.pitch": -10.0, "root.lift": 0.0}
    arm(channels, "R", 140.0, 12.0, 30.0)
    arm(channels, "L", 120.0, 22.0, 15.0)
    leg(channels, "R", -8.0, 8.0, 35.0)
    leg(channels, "L", -12.0, 12.0, 35.0)
    return channels


def rise_pose():
    channels = {"spine.pitch": 4.0, "head.pitch": -6.0, "root.lift": 0.06}
    arm(channels, "R", 160.0, 10.0, 40.0)
    arm(channels, "L", 135.0, 20.0, 25.0)
    leg(channels, "R", 60.0, 105.0, 20.0)
    leg(channels, "L", 35.0, 95.0, 25.0)
    return channels


def apex_pose():
    channels = {"spine.pitch": 0.0, "head.pitch": -4.0, "root.lift": 0.06}
    arm(channels, "R", 140.0, 15.0, 45.0)
    arm(channels, "L", 110.0, 30.0, 35.0)
    leg(channels, "R", 50.0, 75.0, 15.0)
    leg(channels, "L", 30.0, 60.0, 20.0)
    return channels


def fall_pose():
    channels = {"spine.pitch": -4.0, "head.pitch": -2.0, "root.lift": 0.02}
    arm(channels, "R", 110.0, 20.0, 55.0, 15.0)
    arm(channels, "L", 90.0, 35.0, 50.0, 15.0)
    leg(channels, "R", 22.0, 28.0, 15.0)
    leg(channels, "L", -2.0, 18.0, 20.0)
    return channels


def tuck_pose():
    channels = {"spine.pitch": 30.0, "neck.pitch": 10.0, "head.pitch": 10.0, "root.lift": 0.08}
    arm(channels, "R", 40.0, 70.0, 20.0)
    arm(channels, "L", 50.0, 75.0, 20.0)
    leg(channels, "R", 110.0, 140.0, 30.0)
    leg(channels, "L", 104.0, 135.0, 30.0)
    return channels


def jump(frame, count):
    keys = [
        (0, stand()),
        (2, crouch_pose()),
        (3, crouch_pose()),
        (5, launch_pose()),
        (8, rise_pose()),
        (11, apex_pose()),
        (14, fall_pose()),
        (count - 1, fall_pose()),
    ]
    return pose(interpolate(keys, frame))


def double_jump(frame, count):
    keys = [
        (0, fall_pose()),
        (2, tuck_pose()),
        (10, tuck_pose()),
        (13, fall_pose()),
        (count - 1, fall_pose()),
    ]
    channels = interpolate(keys, frame)
    channels["root.pitch"] = 360.0 * smoothstep((frame - 1) / 11.0)
    channels["root.pivot"] = 1.0
    channels["root.lift"] = 0.04
    channels["root.x"] = 0.02
    channels["root.center"] = smoothstep(frame / 2.0) * (1.0 - smoothstep((frame - 11) / 3.0))
    return pose(channels, "body")


def pit_flail(channels, frame):
    wave = 1.9 * frame
    channels["shoulder_R.swing"] += 22.0 * math.sin(wave)
    channels["shoulder_L.swing"] += 22.0 * math.sin(wave + 2.2)
    channels["elbow_R.bend"] += 10.0 + 10.0 * math.sin(wave + 1.0)
    channels["elbow_L.bend"] += 20.0 * math.sin(wave + 3.0)
    channels["hip_R.swing"] += 25.0 * math.sin(1.5 * frame)
    channels["hip_L.swing"] -= 25.0 * math.sin(1.5 * frame)
    channels["knee_R.bend"] += 25.0 * math.sin(1.5 * frame + 1.0)
    channels["knee_L.bend"] += 25.0 * math.sin(1.5 * frame + 2.5)
    return channels


def death_pit(frame, count):
    surprised = {"spine.pitch": -6.0, "head.pitch": -12.0}
    arm(surprised, "R", 40.0, 30.0, 20.0)
    arm(surprised, "L", 30.0, 30.0, 20.0)
    leg(surprised, "R", 6.0, 8.0)
    leg(surprised, "L", -4.0, 6.0)
    flailing = {"spine.pitch": -8.0, "head.pitch": -18.0}
    arm(flailing, "R", 158.0, 12.0, 40.0)
    arm(flailing, "L", 132.0, 22.0, 25.0)
    leg(flailing, "R", 25.0, 45.0, 20.0)
    leg(flailing, "L", -10.0, 30.0, 25.0)
    channels = interpolate([(0, surprised), (3, flailing), (count - 1, flailing)], frame)
    if frame >= 3:
        pit_flail(channels, frame)
    progress = clamp((frame - 1) / (count - 2))
    hop = 0.03 * math.sin(math.pi * clamp(frame / 3.0))
    channels["root.z"] = hop - 0.25 * progress - 1.15 * progress * progress
    channels["root.scale"] = 1.0 - 0.4 * progress
    channels["root.pivot"] = 0.9
    return pose(channels, None)


def faint_keys():
    hit = {"spine.pitch": -14.0, "neck.pitch": -8.0, "head.pitch": -22.0, "root.pitch": -4.0, "root.x": -0.03}
    arm(hit, "R", -25.0, 35.0, 45.0)
    arm(hit, "L", -15.0, 35.0, 45.0)
    leg(hit, "R", 6.0, 10.0)
    leg(hit, "L", -4.0, 8.0)
    stagger = {"spine.pitch": -20.0, "head.pitch": -15.0, "root.pitch": -12.0, "root.x": -0.08}
    arm(stagger, "R", 70.0, 40.0, 60.0)
    arm(stagger, "L", 50.0, 40.0, 60.0)
    leg(stagger, "R", 25.0, 35.0)
    leg(stagger, "L", -28.0, 25.0)
    falling = {"spine.pitch": 10.0, "head.pitch": 18.0, "root.pitch": -50.0, "root.x": 0.0, "face.blink": 0.5}
    arm(falling, "R", 30.0, 30.0, 70.0)
    arm(falling, "L", 90.0, 35.0, 40.0)
    leg(falling, "R", 45.0, 55.0, 20.0)
    leg(falling, "L", 25.0, 40.0, 20.0)
    impact = {"spine.pitch": 6.0, "head.pitch": 10.0, "root.pitch": -92.0, "root.x": 0.05, "face.blink": 1.0}
    arm(impact, "R", 40.0, 30.0, 70.0)
    arm(impact, "L", 100.0, 30.0, 55.0)
    leg(impact, "R", 50.0, 60.0, 10.0)
    leg(impact, "L", 30.0, 35.0, 10.0)
    bounce = {"spine.pitch": 3.0, "head.pitch": 4.0, "root.pitch": -84.0, "root.x": 0.05, "root.lift": 0.03, "face.blink": 1.0}
    arm(bounce, "R", 50.0, 28.0, 70.0)
    arm(bounce, "L", 70.0, 28.0, 65.0)
    leg(bounce, "R", 40.0, 55.0, 10.0)
    leg(bounce, "L", 20.0, 25.0, 10.0)
    rest = {"head.pitch": -4.0, "root.pitch": -90.0, "root.x": 0.05, "face.blink": 1.0}
    arm(rest, "R", 25.0, 30.0, 75.0)
    arm(rest, "L", 35.0, 30.0, 65.0)
    leg(rest, "R", 38.0, 70.0, 0.0)
    leg(rest, "L", 18.0, 30.0, 0.0)
    for channels in (hit, stagger, falling, impact, bounce, rest):
        channels["root.pivot"] = 0.9
    return hit, stagger, falling, impact, bounce, rest


def death_faint(frame, count):
    hit, stagger, falling, impact, bounce, rest = faint_keys()
    start = dict(stand())
    start["root.pivot"] = 0.9
    keys = [
        (0, start),
        (3, hit),
        (6, stagger),
        (10, falling),
        (13, impact),
        (15, bounce),
        (18, rest),
        (count - 1, rest),
    ]
    return pose(interpolate(keys, frame), "body")


def celebrate():
    channels = {"spine.pitch": -6.0, "neck.pitch": -4.0, "head.pitch": -10.0}
    arm(channels, "R", 165.0, 8.0, 45.0, -10.0)
    arm(channels, "L", 140.0, 15.0, 35.0, -10.0)
    leg(channels, "R", 78.0, 95.0, 25.0)
    leg(channels, "L", -6.0, 6.0)
    return pose(channels)


def slide(frame, count):
    phase = TAU * frame / count
    shake = math.sin(2.0 * phase)
    sway = math.sin(phase)
    channels = {
        "pelvis.pitch": -10.0,
        "spine.pitch": -42.0 + 2.0 * shake,
        "spine.yaw": 3.0 * sway,
        "neck.pitch": 8.0,
        "head.pitch": 14.0 + 3.0 * math.sin(phase - 0.8),
        "root.lift": -0.04,
    }
    arm(channels, "R", -55.0 + 6.0 * sway, 20.0 + 5.0 * shake, 25.0, 5.0)
    arm(channels, "L", 45.0 + 5.0 * math.sin(phase + 1.0), 25.0, 15.0, 5.0)
    leg(channels, "R", 90.0 + 1.5 * shake, 4.0, 60.0)
    leg(channels, "L", 70.0, 150.0 + 3.0 * sway, 10.0, 8.0)
    return pose(channels, "body")


ANIMATION_BUILDERS = {
    "idle": idle,
    "run": run,
    "jump": jump,
    "doubleJump": double_jump,
    "deathPit": death_pit,
    "deathFaint": death_faint,
    "slide": slide,
}

POSE_BUILDERS = {
    "idle": lambda: idle(0, 18),
    "run": lambda: run(3, 16),
    "jump": lambda: jump(8, 16),
    "celebrate": celebrate,
}


def pose_for(animation, frame, count):
    return ANIMATION_BUILDERS[animation](frame, count)


def still_pose(name):
    return POSE_BUILDERS[name]()
