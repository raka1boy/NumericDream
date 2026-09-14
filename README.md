hiii hiiii hello this is Numeric dream, a program that i wanted to develop since i was 8 years old.  

Windows is tier-1 support, linux is very shabby.
I built this on zig version 0.17.0-dev.1676+c9dc9b798
Check out docs/manual for a slop manual(i checked everything and fixed some moments, so it is pretty much consistent with the actual app.)

Numeric dream is a program for rendering 3d fractals using WGPU shaders. It takes heavy inspiration from Mandelbulb3D(https://github.com/thargor6/mb3d) and Fragmentarium(https://github.com/Syntopia/Fragmentarium). Current supported features are:

GPU ray-marched 3d fractals
Combine modes between instances
Mixins to the original fractals
2D mode(althouth its kinda bad, mayb one day...)
Empty-space acceleration via voxel cascade
@param directives of wgpu as parameters in the app.
multi-stop color strip with each color being of different material
that includes reflection, refraction, roughness, transparency, subsurface, iridescence
realistic lighting via photon-map(still needs some work but im tire.d....)
skyboxes
volumetric fog
non-euqlidian space warps
freefly camera with DoF and stereoscopic render
MC render for realistic and juicy light
Video rendering with keyframe animations

overall i'd say i'm proud of this, as this project taught me a lot about zig, specifically about zig build system, which always was a very difficult thing for me to reason about. 

Performance of this app is not that great, but all of the tests happened on my laptop with a beast of a gpu (amd radeon 780m) and i could semi-comfortably render small animations. 


AI usage policy:

Manual, UI, some platform specific code, some formulas were written using claude.
Everything else is quality, pelmeni-fed humanslop.
My motivation behind using ai for these things is that

1) I hate and despise writing UIs. I am bad at it, and i will never ever need this skill.

2) Fractal formulas are rather linear and brainless to implement.

3) this is a for-fun project, so i prioritize having fun with it over quality to some extent.

4) Writing manuals is also something that i would rather not do.