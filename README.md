hiii hiiii hello this is Numeric dream, a program that i wanted to develop since i was 8 years old.  

Windows is tier-1 support, linux is very shabby.
I built this on zig version 0.17.0-dev.1676+c9dc9b798
Check out docs/manual for a slop manual(i checked everything and fixed some moments, so it is pretty much consistent with the actual app.)

Numeric dream is a program for rendering 3d fractals using WGPU shaders. It takes heavy inspiration from Mandelbulb3D(https://github.com/thargor6/mb3d) and Fragmentarium(https://github.com/Syntopia/Fragmentarium). Current supported features are:

Realtime GPU ray-marcher for DE fractals(and SDF formulas in general) using WebGPU. Shaders are compiled in the bacground while the app runs.
main loop is event driven, so if app does nothing, it uses nothing.

ND has a freefly camera with no gimbal lock with wasd to move, mouse drag or arrows, and q/e to roll. z/c to slow down or speed up. camera also can enter play mode, which allows to walk on the fractal. in this mode z and c also increase and decrease your size. clicking lmp in this mode will dent a fractal temborarily.

hi-qual renders of the scene. you can also toggle each objects visibility.
undo/redo with ctrl-z and ctrl-alt-z with 100 steps. 
gpu timing to perftest. --perf also is included. 
full unicode support(is only used by one shader lol.)

4 fractals per scene. each has 3 mixin fractals. each of the 4 fractals can choose how they blend with others, be it smooth blending, some sort of union, etc. 
wgsl formulas allow for external @param parameter declaration. they will show up as sliders in the actual app's frontend. This feature supports images(png,jpeg,tga,bmp,hdr).
fft view of a fractal which will show it as a 3d fourier magnitude spectrum(i like to call it frequency cloud).

each fractal may have up to 16 stops of a color strip. each stop is its own material. fractals are colored by orbit trap. there are different traps' shapes aveliable such as shpere, sphere shell, box shell, cross and torus ring.
each material has these parameters:
glossiness, reflectiveness, transparency, refraction, dispersion, iridescence, subsurface scattering. each one is realistic. i killed like weeks trying to get them to be realistic. 

each scene may have 8 light sources. light source can be either emissive point, global directional, or a ray(which can be a flashlight or a laser.)
light in general is also a point of interest of this app. it is simulated with a combination of photon mapping and MC render to provide realistic simulation of what it would act like irl. 
scene also may have a skybox that can either be procedural or hdr, png, or jpeg image. it lights up a fractal and forms a backdrop.

app supports 4 instances of volumetric fog which disperse light etc, you know the drill.
it also has spatial warps which can be used to distort space. maximum is 4 per scene.
app also supports 2 particle systems per scene. particles can be simple circles or sdf spheres. particles have velocity and time parameter.

ND has kind of functioning empty space accelerator, and plethora of other micro optimizations. it also has a simple render mode, where you can enable specific parts of renderer, or render a geometry-only object. app also has optional approximations which you can enable to ease the render specifically on the parts that matter to you. or dont. do whatever you want idc.
to understant what eats performance in your scene you have a diagnostics toolkit at your disposal. hotspot view will show you where renderer spends the most time in your scene, and you can filter various parts. most of the time its lighting.

app also has a chain of 8 screenspace shaders. they can read the g-buffer, so depth, normals and dof circle of confusion.

theres a 2d mode to see inside the fractal. since it is basically free compared to 3d, you can use it to generate some pretty heavy zooms, though more often than not its quite useless.

the app can export your scenes as a png, jpeg or bmp image up to 16384^2 in tiles. also supports stereoscopic render
app can also render animation via keyframe animation.(basically just renders a lot of frames and tries to use ffmpeg to assemble them into an mp4)
your scene can also be exported as an .obj or .ply.
you can also save a scene as a .dream file.

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
