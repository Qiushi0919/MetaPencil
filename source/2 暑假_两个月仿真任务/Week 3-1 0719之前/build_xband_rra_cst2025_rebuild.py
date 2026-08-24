# CST Studio Suite 2025 - corrected rebuild of the X-band 1-bit RRA cell.
# Paste the COMPLETE file into a fresh `%edit` window, save, and close it.
# It operates on the currently active blank Microwave Studio project.
#
# All dimensions, materials, diode RLC values, frequency limits and incidence
# angles are registered with MakeSureParameterExists and referenced by CST geometry.
# Rx/Cx control the left-right PIN pair; Ry/Cy control the top-bottom PIN pair.
# One CST project can therefore run 00/01/10/11 as four Parameter Sweep sequences.
# For the ON state use Cx/Cy = C_on_approx, not zero: a zero capacitance is
# a degenerate value for a parameterized RLCSerial element in CST.

from __future__ import annotations

from typing import Union

from cst.interface import get_current_project


# -----------------------------------------------------------------------------
# User switch. Build the model without automatically starting the solver.
# -----------------------------------------------------------------------------
RUN_SOLVER = False


# -----------------------------------------------------------------------------
# Dimensions and material data explicitly reported in the paper (mm, GHz).
# -----------------------------------------------------------------------------
PAPER = {
    "period": 15.0,
    "h_f4bm": 3.0,
    "h_fr4": 0.5,
    "h_bond": 0.1,
    "w_outer": 6.0,       # W1: outer edge of each trapezoid
    "w_inner": 5.3,       # W2: central square and inner trapezoid edge
    "arm_length": 2.9,    # L1
    "gap": 0.3,           # S1
    "choke_radius": 2.5,  # R1
    "choke_angle": 60.0,  # alpha1, degrees
    "eps_f4bm": 2.65,
    "tand_f4bm": 0.003,
    "eps_fr4": 4.4,
    "tand_fr4": 0.02,
    "eps_bond": 3.52,
    "tand_bond": 0.004,
    "r_on": 1.0,
    "r_off": 10.0,
    "l_diode_nh": 0.45,
    "c_off_pf": 0.16,
}


# -----------------------------------------------------------------------------
# Not specified in the paper. These are reasonable STARTING values, not claims
# about the fabricated prototype. Sweep these after the paper geometry works.
# -----------------------------------------------------------------------------
ASSUMED = {
    "copper_thickness": 0.035,
    "copper_conductivity": 5.8e7,
    "via_diameter": 0.30,
    "antipad_diameter": 0.80,
    "bias_line_width": 0.20,
    "common_return_y": 2.0,
    "c_on_approx_pf": 1000.0,
    "fan_arc_segments": 24,
}


Scalar = Union[float, int, str]


def n(value: Scalar) -> str:
    """CST expression string or compact decimal literal."""
    if isinstance(value, str):
        return value
    if abs(value) < 1e-14:
        value = 0.0
    return f"{value:.12g}"


def add_history(project, title: str, commands: str) -> None:
    # get_current_project() exposes the active 3-D model through model3d.
    project.model3d.add_to_history(title, commands.strip())


def brick(name: str, component: str, material: str,
          xr: tuple[Scalar, Scalar], yr: tuple[Scalar, Scalar],
          zr: tuple[Scalar, Scalar]) -> str:
    return f"""
With Brick
    .Reset
    .Name "{name}"
    .Component "{component}"
    .Material "{material}"
    .Xrange "{n(xr[0])}", "{n(xr[1])}"
    .Yrange "{n(yr[0])}", "{n(yr[1])}"
    .Zrange "{n(zr[0])}", "{n(zr[1])}"
    .Create
End With
"""


def cylinder(name: str, component: str, material: str,
             x: Scalar, y: Scalar, radius: Scalar,
             z0: Scalar, z1: Scalar) -> str:
    return f"""
With Cylinder
    .Reset
    .Name "{name}"
    .Component "{component}"
    .Material "{material}"
    .OuterRadius "{n(radius)}"
    .InnerRadius "0"
    .Axis "z"
    .Zrange "{n(z0)}", "{n(z1)}"
    .Xcenter "{n(x)}"
    .Ycenter "{n(y)}"
    .Segments "0"
    .Create
End With
"""


def extruded_polygon(name: str, component: str, material: str,
                     points: list[tuple[Scalar, Scalar]],
                     z0: Scalar, height: Scalar) -> str:
    if len(points) < 3:
        raise ValueError("A polygon needs at least three points")
    p0 = points[0]
    path = [f'    .Point "{n(p0[0])}", "{n(p0[1])}"']
    path.extend(
        f'    .LineTo "{n(x)}", "{n(y)}"' for x, y in points[1:]
    )
    path.append(f'    .LineTo "{n(p0[0])}", "{n(p0[1])}"')
    return f"""
With Extrude
    .Reset
    .Name "{name}"
    .Component "{component}"
    .Material "{material}"
    .Mode "Pointlist"
    .Height "{n(height)}"
    .Twist "0"
    .Taper "0"
    .Origin "0", "0", "{n(z0)}"
    .Uvector "1", "0", "0"
    .Vvector "0", "1", "0"
{chr(10).join(path)}
    .Create
End With
"""


def sector_points(apex: tuple[Scalar, Scalar], direction_deg: float,
                  radius_name: str, angle_name: str,
                  segments: int) -> list[tuple[Scalar, Scalar]]:
    """Parametric sector whose apex is exactly at the associated via center."""
    pts = [apex]
    for idx in range(segments + 1):
        # CST trigonometric expressions use radians. alpha1 is stored in
        # degrees, so multiply the generated angle by pi/180 numerically.
        angle = (
            f"({n(direction_deg)}-{angle_name}/2+"
            f"{angle_name}*{idx}/{segments})*0.0174532925199433"
        )
        pts.append((
            f"({n(apex[0])})+{radius_name}*cos({angle})",
            f"({n(apex[1])})+{radius_name}*sin({angle})",
        ))
    return pts


def lumped_diode(name: str, p1: tuple[Scalar, Scalar, Scalar],
                  p2: tuple[Scalar, Scalar, Scalar],
                  resistance: str, capacitance: str) -> str:
    # CST 2025's Lumped Network Element expects inductance in H and
    # capacitance in F even though the project display units are nH/pF.
    # Lpin and Cx/Cy are kept in convenient nH/pF Parameter List units and
    # converted here at the element interface.
    return f"""
With LumpedElement
    .Reset
    .SetName "{name}"
    .Folder "PIN_Diodes"
    .SetType "RLCSerial"
    .SetR "{n(resistance)}"
    .SetL "Lpin*1e-9"
    .SetC "{n(capacitance)}*1e-12"
    .SetP1 "False", "{n(p1[0])}", "{n(p1[1])}", "{n(p1[2])}"
    .SetP2 "False", "{n(p2[0])}", "{n(p2[1])}", "{n(p2[2])}"
    .Create
End With
"""


def material(name: str, epsilon: Scalar, tand: Scalar,
             color: tuple[float, float, float]) -> str:
    return f"""
With Material
    .Reset
    .Name "{name}"
    .Folder ""
    .FrqType "all"
    .Type "Normal"
    .SetMaterialUnit "GHz", "mm"
    .Epsilon "{n(epsilon)}"
    .Mue "1"
    .Kappa "0"
    .TanD "{n(tand)}"
    .TanDFreq "10"
    .TanDGiven "True"
    .Colour "{n(color[0])}", "{n(color[1])}", "{n(color[2])}"
    .Wireframe "False"
    .Create
End With
"""


def parameter_block() -> str:
    """Register every sweepable value in CST's Parameter List."""
    parameters = {
        "p": PAPER["period"],
        "h1": PAPER["h_f4bm"],
        "h2": PAPER["h_fr4"],
        "hbond": PAPER["h_bond"],
        "W1": PAPER["w_outer"],
        "W2": PAPER["w_inner"],
        "L1": PAPER["arm_length"],
        "S1": PAPER["gap"],
        "R1": PAPER["choke_radius"],
        "alpha1": PAPER["choke_angle"],
        "eps_f4bm": PAPER["eps_f4bm"],
        "tand_f4bm": PAPER["tand_f4bm"],
        "eps_bond": PAPER["eps_bond"],
        "tand_bond": PAPER["tand_bond"],
        "eps_fr4": PAPER["eps_fr4"],
        "tand_fr4": PAPER["tand_fr4"],
        "R_on": PAPER["r_on"],
        "R_off": PAPER["r_off"],
        "C_off": PAPER["c_off_pf"],
        "C_on_approx": ASSUMED["c_on_approx_pf"],
        # Active diode-pair parameters used by the four lumped elements.
        # Initial values are state 00 (both pairs OFF).
        "Rx": PAPER["r_off"],
        "Cx": PAPER["c_off_pf"],
        "Ry": PAPER["r_off"],
        "Cy": PAPER["c_off_pf"],
        "Lpin": PAPER["l_diode_nh"],
        "tcu": ASSUMED["copper_thickness"],
        "sigma_cu": ASSUMED["copper_conductivity"],
        "via_d": ASSUMED["via_diameter"],
        "antipad_d": ASSUMED["antipad_diameter"],
        "bias_w": ASSUMED["bias_line_width"],
        "common_return_y": ASSUMED["common_return_y"],
        "fmin": 8.0,
        "fmax": 12.0,
        "theta_inc": 0.0,
        "phi_inc": 0.0,
    }
    return "\n".join(
        f'MakeSureParameterExists "{name}", "{n(value)}"'
        for name, value in parameters.items()
    )


def build_current_project(project) -> None:
    # CST expressions, rather than Python-evaluated numbers, are used by every
    # shape so the History List can rebuild the model during Parameter Sweep.
    z_patch0 = "0"
    z_patch1 = "tcu"
    z_f4_top = "0"
    z_f4_bot = "-h1"
    z_gnd_top = "-h1"
    z_gnd_bot = "-h1-tcu"
    z_bond_top = "-h1-tcu"
    z_bond_bot = "-h1-tcu-hbond"
    z_choke_top = "-h1-tcu-hbond"
    z_choke_bot = "-h1-2*tcu-hbond"
    z_fr4_top = "-h1-2*tcu-hbond"
    z_fr4_bot = "-h1-2*tcu-hbond-h2"
    z_bias_top = "-h1-2*tcu-hbond-h2"
    z_bias_bot = "-h1-3*tcu-hbond-h2"

    # The paper drawing places each outer via at the trapezoid center.
    via_offset = "W2/2+S1+L1/2"
    outer_vias = {
        "xp": (via_offset, "0"),
        "xm": (f"-({via_offset})", "0"),
        "yp": ("0", via_offset),
        "ym": ("0", f"-({via_offset})"),
    }
    all_vias = {"center": ("0", "0"), **outer_vias}

    add_history(project, "Define sweepable CST parameters", parameter_block())

    units_and_solver = """
With Units
    .Geometry "mm"
    .Frequency "GHz"
    .Time "ns"
    .Voltage "V"
    .Current "A"
    .Resistance "Ohm"
    .Conductance "Siemens"
    .Capacitance "pF"
    .Inductance "nH"
    .TemperatureUnit "Kelvin"
End With
Solver.FrequencyRange "fmin", "fmax"
ChangeSolverType "HF Frequency Domain"
"""
    add_history(project, "Units, frequency range and solver", units_and_solver)

    materials = "".join(
        [
            material("F4BM", "eps_f4bm", "tand_f4bm",
                     (0.45, 0.85, 0.45)),
            material("Rogers_4450F", "eps_bond", "tand_bond",
                     (0.75, 0.35, 0.45)),
            material("FR4_Custom", "eps_fr4", "tand_fr4",
                     (0.35, 0.45, 0.90)),
            f"""
With Material
    .Reset
    .Name "Copper_Custom"
    .Folder ""
    .FrqType "all"
    .Type "Lossy metal"
    .SetMaterialUnit "GHz", "mm"
    .Epsilon "1"
    .Mue "1"
    .Kappa "sigma_cu"
    .TanD "0"
    .Colour "1", "0.55", "0"
    .Wireframe "False"
    .Create
End With
""",
        ]
    )
    add_history(project, "Create materials", materials)

    dielectrics = "".join(
        [
            brick("F4BM", "Dielectrics", "F4BM",
                  ("-p/2", "p/2"), ("-p/2", "p/2"),
                  (z_f4_bot, z_f4_top)),
            brick("Bonding_Film", "Dielectrics", "Rogers_4450F",
                  ("-p/2", "p/2"), ("-p/2", "p/2"),
                  (z_bond_bot, z_bond_top)),
            brick("FR4", "Dielectrics", "FR4_Custom",
                  ("-p/2", "p/2"), ("-p/2", "p/2"),
                  (z_fr4_bot, z_fr4_top)),
        ]
    )
    add_history(project, "Create dielectric stack", dielectrics)

    # Remove dielectric wherever the solid-copper vias pass.  Without these
    # Boolean holes CST's overlap priority may retain dielectric instead of
    # copper inside the substrate, electrically breaking the bias vias.
    dielectric_via_holes = ""
    dielectric_layers = [
        ("F4BM", z_f4_bot, z_f4_top),
        ("Bonding_Film", z_bond_bot, z_bond_top),
        ("FR4", z_fr4_bot, z_fr4_top),
    ]
    for layer_name, layer_z0, layer_z1 in dielectric_layers:
        for via_name, (x, y) in all_vias.items():
            tool_name = f"Via_Hole_{layer_name}_{via_name}"
            dielectric_via_holes += cylinder(
                tool_name, "Boolean_Tools", "Vacuum",
                x, y, "via_d/2", layer_z0, layer_z1,
            )
            dielectric_via_holes += (
                f'Solid.Subtract "Dielectrics:{layer_name}", '
                f'"Boolean_Tools:{tool_name}"\n'
            )
    add_history(
        project, "Cut via holes through dielectric stack",
        dielectric_via_holes,
    )

    # Top central square and four trapezoidal arms.
    inner = "W2/2+S1"
    outer = "W2/2+S1+L1"
    top_metal = brick(
        "Center_Patch", "Top_Metal", "Copper_Custom",
        ("-W2/2", "W2/2"), ("-W2/2", "W2/2"),
        (z_patch0, z_patch1),
    )
    top_metal += extruded_polygon(
        "Trap_XP", "Top_Metal", "Copper_Custom",
        [(inner, "-W2/2"), (outer, "-W1/2"),
         (outer, "W1/2"), (inner, "W2/2")],
        z_patch0, "tcu",
    )
    top_metal += extruded_polygon(
        "Trap_XM", "Top_Metal", "Copper_Custom",
        [(f"-({inner})", "-W2/2"), (f"-({inner})", "W2/2"),
         (f"-({outer})", "W1/2"), (f"-({outer})", "-W1/2")],
        z_patch0, "tcu",
    )
    top_metal += extruded_polygon(
        "Trap_YP", "Top_Metal", "Copper_Custom",
        [("-W2/2", inner), ("W2/2", inner),
         ("W1/2", outer), ("-W1/2", outer)],
        z_patch0, "tcu",
    )
    top_metal += extruded_polygon(
        "Trap_YM", "Top_Metal", "Copper_Custom",
        [("-W2/2", f"-({inner})"), ("-W1/2", f"-({outer})"),
         ("W1/2", f"-({outer})"), ("W2/2", f"-({inner})")],
        z_patch0, "tcu",
    )
    add_history(project, "Create top square and trapezoidal patches", top_metal)

    # Ground plane followed by five antipad Boolean subtractions.
    ground = brick(
        "Ground", "Ground_Metal", "Copper_Custom",
        ("-p/2", "p/2"), ("-p/2", "p/2"),
        (z_gnd_bot, z_gnd_top),
    )
    for name, (x, y) in all_vias.items():
        tool_name = f"Antipad_Tool_{name}"
        ground += cylinder(
            tool_name, "Boolean_Tools", "Vacuum",
            x, y, "antipad_d/2", f"({z_gnd_bot})-tcu", f"({z_gnd_top})+tcu",
        )
        ground += (
            f'Solid.Subtract "Ground_Metal:Ground", '
            f'"Boolean_Tools:{tool_name}"\n'
        )
    add_history(project, "Create ground and via antipads", ground)

    # Five solid-copper bias vias. A solid cylinder is the standard first-order
    # approximation when drill/barrel dimensions are not reported.
    vias = ""
    for name, (x, y) in all_vias.items():
        vias += cylinder(
            f"Via_{name}", "Bias_Vias", "Copper_Custom",
            x, y, "via_d/2", z_bias_bot, z_patch1,
        )
    add_history(project, "Create five bias vias", vias)

    # Four radial stubs. Their apexes coincide with the four trapezoid vias.
    # Fig. 1(c) shows tangential, not radially outward, fan orientations. Each
    # fan axis is the local outward radial direction rotated +90 degrees:
    # east via -> north, north -> west, west -> south, south -> east.
    choke_directions = {"xp": 90.0, "xm": -90.0, "yp": 180.0, "ym": 0.0}
    chokes = ""
    for name, apex in outer_vias.items():
        pts = sector_points(
            apex, choke_directions[name], "R1", "alpha1",
            int(ASSUMED["fan_arc_segments"]),
        )
        chokes += extruded_polygon(
            f"RF_Choke_{name}", "RF_Chokes", "Copper_Custom",
            pts, z_choke_bot, "tcu",
        )
    add_history(project, "Create four radial RF chokes", chokes)

    # Bottom bias network. The paper does not dimension this routing. The four
    # outer lines leave through their nearest cell edges. The common-cathode
    # return is routed to +x at y=common_return_y to avoid line crossings.
    half_line = "bias_w/2"
    return_y = "common_return_y"
    bias = "".join(
        [
            brick("Bias_XP", "Bottom_Bias", "Copper_Custom",
                  (via_offset, "p/2"), (f"-({half_line})", half_line),
                  (z_bias_bot, z_bias_top)),
            brick("Bias_XM", "Bottom_Bias", "Copper_Custom",
                  ("-p/2", f"-({via_offset})"), (f"-({half_line})", half_line),
                  (z_bias_bot, z_bias_top)),
            brick("Bias_YP", "Bottom_Bias", "Copper_Custom",
                  (f"-({half_line})", half_line), (via_offset, "p/2"),
                  (z_bias_bot, z_bias_top)),
            brick("Bias_YM", "Bottom_Bias", "Copper_Custom",
                  (f"-({half_line})", half_line), ("-p/2", f"-({via_offset})"),
                  (z_bias_bot, z_bias_top)),
            brick("Bias_Common_V", "Bottom_Bias", "Copper_Custom",
                  (f"-({half_line})", half_line), ("0", return_y),
                  (z_bias_bot, z_bias_top)),
            brick("Bias_Common_H", "Bottom_Bias", "Copper_Custom",
                  ("0", "p/2"),
                  (f"{return_y}-{half_line}", f"{return_y}+{half_line}"),
                  (z_bias_bot, z_bias_top)),
        ]
    )
    add_history(project, "Create assumed bottom bias routing", bias)

    # PIN lumped elements. Left/right share Rx/Cx; top/bottom share Ry/Cy.
    # Parameter Sweep sequences change these four CST parameters directly.
    # Put each terminal at the midpoint of the vertical metal side face facing
    # the gap.  It must lie on a conductor face, not inside a lossy-metal solid
    # and not on the ambiguous intersection of its top and side faces.
    diode_z = "tcu/2"
    diodes = "".join(
        [
            lumped_diode(
                "D_XP", ("W2/2", "0", diode_z),
                ("W2/2+S1", "0", diode_z), "Rx", "Cx",
            ),
            lumped_diode(
                "D_XM", ("-W2/2", "0", diode_z),
                ("-W2/2-S1", "0", diode_z), "Rx", "Cx",
            ),
            lumped_diode(
                "D_YP", ("0", "W2/2", diode_z),
                ("0", "W2/2+S1", diode_z), "Ry", "Cy",
            ),
            lumped_diode(
                "D_YM", ("0", "-W2/2", diode_z),
                ("0", "-W2/2-S1", diode_z), "Ry", "Cy",
            ),
        ]
    )
    add_history(project, "Create parameterized PIN diode pairs", diodes)

    boundary_and_ports = """
With Boundary
    .Xmin "unit cell"
    .Xmax "unit cell"
    .Ymin "unit cell"
    .Ymax "unit cell"
    .Zmin "expanded open"
    .Zmax "expanded open"
    .Xsymmetry "none"
    .Ysymmetry "none"
    .Zsymmetry "none"
    .ApplyInAllDirections "False"
End With

With FloquetPort
    .Reset
    .SetDialogTheta "theta_inc"
    .SetDialogPhi "phi_inc"
    .SetSortCode "+beta/pw"
    .SetCustomizedListFlag "False"
    .Port "Zmax"
    .SetNumberOfModesConsidered "2"
    .SetDistanceToReferencePlane "0"
    .SetUseCircularPolarization "False"
End With

With FloquetPort
    .Reset
    .SetDialogTheta "theta_inc"
    .SetDialogPhi "phi_inc"
    .SetSortCode "+beta/pw"
    .SetCustomizedListFlag "False"
    .Port "Zmin"
    .SetNumberOfModesConsidered "2"
    .SetDistanceToReferencePlane "0"
    .SetUseCircularPolarization "False"
End With
"""
    add_history(project, "Unit-cell boundaries and Floquet ports", boundary_and_ports)

    if RUN_SOLVER:
        project.model3d.run_solver()


def main() -> None:
    active_project = get_current_project()
    if active_project is None:
        raise RuntimeError("Open a blank Microwave Studio project first")

    build_current_project(active_project)
    print("Built one parameterized full-bias RRA unit cell in the current project.")
    print("Use C_on_approx (1000 pF), not zero, for an ON-state Cx or Cy.")
    print("Sequence 00: Rx=10,Cx=0.16,Ry=10,Cy=0.16")
    print("Sequence 01: Rx=10,Cx=0.16,Ry=1,Cy=C_on_approx")
    print("Sequence 10: Rx=1,Cx=C_on_approx,Ry=10,Cy=0.16")
    print("Sequence 11: Rx=1,Cx=C_on_approx,Ry=1,Cy=C_on_approx")
    if not RUN_SOLVER:
        print("Solver was not started. Inspect geometry, ports and mesh, then save the project.")


# %edit executes the temporary file after it is saved and closed, so call the
# entry point unconditionally instead of relying on a command-line launcher.
main()
