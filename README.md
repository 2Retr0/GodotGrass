# GodotGrass

A grass rendering experiment in the Godot Engine inspired by techniques used in "Ghost of Tsushima". Individual blades of grass are generated with GPU instancing via Godot's MultiMeshInstance node and are colored/animated using a shader-driven approach.

[grass_demo.mp4](https://github.com/user-attachments/assets/1ee5b1b0-7c60-4355-9b12-4f97891798c8)

## Results
### Grass Shading
The color of the grass is dependent on a base and tip color, mixed vertically along the model. A rounder appearance for each blade is created by bending the normals horizontally in the fragment shader. Ambient occlusion is simulated by darkening blades vertically based on their model space height. Grass shadow mapping is enabled by default to improve occlusion shading (at a *very* high performance cost), however, a very close apperance can be recreated by changing the base and tip colors.

Grass blades which are perpendicular to the camera are stretched horizontally in view space as suggested in the "Ghost of Tsushima" GDC talk. Blades are also procedurally bent based on their height (not including wind). The bend angle of each vertex on the blade is based on the total height of the blade along with the height of the vertex along the blade yielding a curved appearance.

A basic 'hacky' lighting model for grass is implemented atop Godot's default lighting model. Ambient lighting is modeled by augmenting the diffuse light with power curve so that vertices facing away from lights are still lit slightly. Subsurface scattering is modeled by adding a separate color based on the angle between the view and light vector. Specular highlights are driven by Godot's default lighting model.

![apperance_demo](https://github.com/user-attachments/assets/a575f5ac-7266-4b18-9a4c-f9c6174d9c86)

### Environmental Factors
To provide a less-uniform appearance to fields of grass, a "clumping factor" parameter was created to clump initial rotational offset for groups of grass blades based on a cellular noise texture. The same noise texture is used to independently clump the heights and maximum bend angles for grass blades. Global grass density can also be controlled using a separate parameter. 

Wind was simulated by scrolling a Perlin noise texture, sampled at different frequencies, to get a wind direction (blade rotational offset) and wind strength (blade bend) at a given time. A high-frequency, low-amplitude simplex domain warp is applied to the noise texture to simulate turbulence from wind—this results in a 'jittering' motion at blades' tips during at wind strength. A global "wind strength" parameter controls how fast the noise texture is scrolled for direction as well as the amplitude of the bend. 

The combination of these features yield a realistic-looking model for grass across a wide-variety of environments.

[environment_demo.mp4](https://github.com/user-attachments/assets/47a70291-777d-43c8-b7ab-4e75d10908c6)

### Level of Detail (LOD)
A simple tile-based LOD system is used to improve performance while maintaining a consistent visual quality. Each LOD tile is driven by a density (denoting how many blades of grass will be distributed along its boundaries) and a mesh (swapping between a hard-coded high-quality and low-quality blade mesh). These properties change depending on the tile's distance from the camera and are updated every time the camera moves into a new tile.

Unfortunately, LOD swapping is very noticable due to the tiled nature of the system. Tile fade-in or seeded random blade placement can possibly alleviate this problem. Since each tile is culled all at once, a tradeoff has to be made between the amount of draw calls and culling performance. At the time of writing this, GPU instancing in Godot can only be achieved using the engine's MultiMeshInstance node. This requires the positions of blades to be calculated on the CPU—a compute shader-based approach could permit a more-performant and dynamic LOD system.

![lod_demo](https://github.com/user-attachments/assets/470badbc-b140-42b1-9930-58e0f88dc18b)

## References
**SimonDev**. **[How do Major Video Games Render Grass?](https://www.youtube.com/watch?v=bp7REZBV4P4)**. (2023).\
**Wohllaib, Eric**. **[Procedural Grass in 'Ghost of Tsushima'](https://www.youtube.com/watch?v=Ibe1JBF5i5Y)**. Game Developers Conference. (2021).

## Attributions
**[Reisen Udongein Inaba (Touhou)](https://skfb.ly/6VCyw)** by **chained_tan** is modified and used under the [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license.\
**[Evening Road 01 (Pure Sky)](https://polyhaven.com/a/evening_road_01_puresky)** by **Jarod Guest** is used under the [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) license. 
