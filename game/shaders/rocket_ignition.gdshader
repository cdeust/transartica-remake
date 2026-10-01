shader_type canvas_item;
render_mode unshaded;

// MIT. Authored granular jet and rolling smoke, not a CFD approximation.
// Reference observations and native calibration: rocket-ignition-20261001.md.
// Frozen visual clock is supplied explicitly; shader TIME is never used.
uniform float visual_seconds = 0.0;
uniform vec2 nozzle = vec2(141.0,103.0);
varying vec2 logical_position;

void vertex() { logical_position = VERTEX; }

float grain(vec2 p) {
	// Authored repeatable pigment lattice; coefficients tune visible breakup.
	return fract(sin(dot(floor(p),vec2(19.0,47.0)))*3151.0);
}

float pigment(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(grain(cell),grain(cell+vec2(1.0,0.0)),f.x),mix(grain(cell+vec2(0.0,1.0)),grain(cell+vec2(1.0)),f.x),f.y);
}


float bayer4(vec2 p) {
	// Ordered 4×4 Bayer threshold on the half-logical-pixel lattice.
	ivec2 c = ivec2(mod(floor(p),4.0));
	int index = c.y*4+c.x;
	const float m[16] = float[16](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
	return (m[index]+0.5)/16.0;
}

// Signed thickness of the ground cloud at p (positive inside), logical px.
float cloud_body(vec2 p, float t, float deck, float contact, float lift) {
	float dx = abs(p.x-nozzle.x);
	float side = sign(p.x-nozzle.x);
	float front = 8.0+62.0*(1.0-exp(-t*0.8)); // decelerating carpet front
	float pile = min(30.0,6.0+t*15.0)*(0.5+0.5*contact); // height at the base
	float profile = pile*pow(max(0.0,1.0-dx/front),0.7);
	// Large billows roll outward along the carpet; finer churn rides on them.
	vec2 roll = vec2((dx-t*20.0)*0.075,(deck-p.y)*0.09-t*0.5);
	float billow = pigment(roll)*0.62+pigment(roll*2.1+vec2(side*3.0,t*0.7))*0.28+pigment(roll*4.7)*0.10;
	float above = deck-p.y-lift*16.0;
	return profile-above+(billow-0.5)*22.0;
}

void fragment() {
	// Half logical pixels become about2native pixels at1440×900.
	vec2 p = floor(logical_position*2.0)/2.0;
	float t = visual_seconds;
	vec2 q = p-nozzle;
	float deck = 105.0; // Source: measured authored deck contact, owner review.
	float ground = max(2.0,deck-nozzle.y); // nozzle → deck distance
	float contact = 1.0-smoothstep(25.0,70.0,ground);
	float lift = smoothstep(20.0,90.0,ground);
	float dither = bayer4(p*2.0);
	// Jet: dense supersonic core, then a wider cooling trail that thins out
	// gradually (no cut). Where it reaches the deck it is crushed and splays.
	float core_length = 16.0+10.0*(1.0-contact); // source: authored, native review
	float along = clamp(q.y/ground,0.0,1.0);
	float coarse = pigment(vec2(q.x*0.45,q.y*0.23-t*13.0));
	float fine = grain(p*2.0+vec2(0.0,floor(t*50.0)*3.0));
	float bend = sin(q.y*0.37-t*16.0)*smoothstep(0.0,30.0,q.y)*0.7;
	float width = 2.0+q.y*0.09+(coarse-0.5)*2.2;
	// Crushed against the deck: the column bulges in the last few pixels.
	float crush = contact*smoothstep(ground-10.0,ground,q.y);
	width += crush*9.0;
	float edge = abs(q.x-bend)/max(width,0.1);
	float density = (1.0-smoothstep(0.55,1.1,edge))*step(0.0,q.y)*step(q.y,ground+1.0);
	density *= exp(-max(0.0,q.y-core_length)/(22.0+coarse*14.0)); // trail thins
	// Splash: two tongues of flame run outward along the deck and cool.
	float run = 6.0+34.0*contact*min(1.0,t*1.6);
	float splash_dx = abs(q.x)/max(run,1.0);
	float tongue_h = 5.0*(1.0-splash_dx)+(pigment(vec2(abs(q.x)*0.3-t*18.0,p.y*0.4))-0.5)*4.0;
	float splash = contact*step(splash_dx,1.0)*step(deck-p.y,tongue_h)*step(p.y,deck+0.5)*(1.0-splash_dx*0.7);
	density = max(density,splash);
	float heat = clamp(1.15-edge*0.7-q.y/(core_length*3.0)+(coarse-0.5)*0.4+fine*0.12,0.0,1.0);
	heat = max(heat*density,splash*(0.75-splash_dx*0.55));
	float diamond = pow(max(0.0,sin(q.y*0.7-t*15.0)),4.0)*(1.0-edge)*0.25*step(q.y,core_length);
	heat = clamp(heat+diamond,0.0,1.0);
	// Hot core opaque; the cooling trail turns to translucent exhaust haze.
	float fire_alpha = smoothstep(0.04,0.55,density);
	vec3 fire = mix(vec3(0.5,0.52,0.58),vec3(0.8,0.25,0.06),smoothstep(0.08,0.3,heat));
	fire = mix(fire,vec3(1.0,0.55,0.08),smoothstep(0.25,0.5,heat));
	fire = mix(fire,vec3(1.0,0.94,0.72),smoothstep(0.5,0.8,heat));
	fire = mix(fire,vec3(1.0),smoothstep(0.82,0.99,heat));
	fire = floor(fire*8.0+dither)/8.0;
	float glow = exp(-edge*edge*0.6)*step(0.0,q.y)*exp(-q.y/40.0)*0.22;
	glow = max(glow,exp(-abs(p.y-deck)/2.5)*exp(-abs(q.x)/18.0)*contact*0.5);
	fire_alpha *= mix(0.55,1.0,smoothstep(0.1,0.35,heat)); // haze stays see-through
	float silhouette = fire_alpha;
	fire_alpha = max(fire_alpha,glow);
	// Ground cloud: exhaust striking the deck piles up at the base, spreads
	// sideways as a carpet whose rolling front decelerates, then lifts and
	// erodes from its rim once the nozzle climbs away. Authored recipe.
	float body = cloud_body(p,t,deck,contact,lift)-lift*12.0;
	// Emboss: compare with the sample toward the moon (upper left) for relief.
	float relief = clamp((body-cloud_body(p+vec2(-1.5,-1.5),t,deck,contact,lift)+lift*12.0)*0.35,-1.0,1.0);
	float dx = abs(q.x);
	float coverage = clamp(body/4.0,0.0,1.0)*smoothstep(0.0,0.08,t);
	coverage *= 1.0-smoothstep(deck+1.0,deck+4.0,p.y); // the deck stops the gas
	float smoke = step(dither*0.9+0.05,coverage);
	// Moonlit crowns, sooty folds, flame-lit underside near the nozzle.
	float shade = clamp(0.55+relief*0.6-clamp(body/30.0,0.0,1.0)*0.2,0.0,1.0);
	shade = floor(shade*5.0+dither)/5.0;
	vec3 cloud = mix(vec3(0.17,0.21,0.28),vec3(0.84,0.88,0.93),shade);
	float warmth = exp(-dx/18.0)*exp(-abs(p.y-deck)/10.0)*contact;
	cloud = mix(cloud,vec3(1.0,0.6,0.22),warmth*0.7);
	float cloud_alpha = smoke;
	// Fade at the authored control-safe bounds rather than clipping a hard wall.
	cloud_alpha *= smoothstep(20.0,30.0,p.x)*(1.0-smoothstep(199.0,209.0,p.x));
	// The rocket jet stays visible: gas never hides the hot core.
	cloud_alpha *= 1.0-silhouette*step(0.6,heat);
	vec3 color = mix(cloud,fire,fire_alpha);
	float alpha = cloud_alpha+fire_alpha*(1.0-cloud_alpha);
	COLOR = vec4(color,alpha);
}
