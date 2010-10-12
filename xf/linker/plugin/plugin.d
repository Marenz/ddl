module plugin;
import common;

import xf.omg.core.LinearAlgebra;
import xf.omg.rt.Common;
import xf.omg.geom.Sphere;
import xf.omg.geom.Plane;

import xf.dog.Dog;
import tango.io.Stdout;

import tango.util.log.Trace;


struct Light {
	vec3	pos;
	vec3	color;
	float	intens;
	
	vec3 sample(vec3 pt) {
		return color * (intens / (pos - pt).sqLength);
	}
}


class TracerPlugin : Plugin {
	const int maxRecursion = 5;
	vec2i windowSize;// = {x:640, y:480};
	vec2i textureSize;// = {x:128, y:128};
	ubyte[] texData;
	uint texId = 0;

	Sphere[]	spheres;
	Plane[]		planes;
	Light[]		lights;
	vec3[]		sphereColors;
	vec3[]		planeColors;
	
	vec3			cameraPos = vec3.zero;
	quat			cameraRot = quat.identity;
	
	
	this(int winW, int winH, int texW, int texH) {
		this.windowSize = vec2i(winW, winH);
		this.textureSize = vec2i(texW, texH);
		texData = new ubyte[textureSize.x * textureSize.y * 3];

		// create the scene
		{
			spheres ~= Sphere(vec3(-4.0, 1.5, -8.0), 3.2);
			sphereColors ~= vec3(1.0, 0.3, 0.1);

			spheres ~= Sphere(vec3(2.5, 1.5, -5.0), 1.2);
			sphereColors ~= vec3(0.2, 1.0, 0.4);

			spheres ~= Sphere(vec3(0.7, -1.5, -4.2), 1.5);
			sphereColors ~= vec3(0.2, 0.4, 1.0);
			
			planes ~= Plane(vec3(0, 1, 0), 4);
			planeColors ~= vec3(0.8, 0.8, 0.8);

			lights ~= Light(vec3(8.0, 30.0, 10.0), vec3(.7, .7, .6), 800.0);
			lights ~= Light(vec3(-5.0, 20.0, 15.0), vec3(.6, .4, .1), 900.0);
			lights ~= Light(vec3(10.0, -3.0, 5.0), vec3(.4, .6, .8), 300.0);
		}
	}
	
	bool blocked(vec3 orig, vec3 src) {
		vec3 v = src - orig;
		float vlen = v.length;
		if (0 == vlen) return false;
		
		Ray r = Ray.fromOrigDir(orig, v * (1.f / vlen));
		Hit hit;
		hit.distance = vlen;
		
		foreach (s; spheres) {
			if (s.intersect(r, hit)) return true;
		}
		foreach (p; planes) {
			if (p.intersect(r, hit)) return true;
		}
		
		return false;
	}
	
	vec3 colorInScene(ref Ray r, int recDepth = 0) {
		Hit hit;
		bool intersection = false;
		
		vec3 primCol = void;
		
		foreach (i, s; spheres) {
			if (s.intersect(r, hit, IntersectFlags.ComputeNormal)) {
				intersection = true;
				primCol = sphereColors[i];
			}
		}
		
		foreach (i, p; planes) {
			if (p.intersect(r, hit, IntersectFlags.ComputeNormal)) {
				intersection = true;
				primCol = planeColors[i];
			}
		}
		
		if (intersection) {
			vec3 color = vec3.zero;
			vec3 poi = r.origin + r.direction * hit.distance;
			
			foreach (l; lights) {
				vec3 v = (l.pos - poi).normalized;
				if (!blocked(poi + v * 0.001f, l.pos - v * 0.001f)) {
					float cosFalloff = dot(v, hit.normal);
					if (cosFalloff > 0) {
						float normDotLight = dot(hit.normal, v);
						vec3 refl = 2.f * (normDotLight) * hit.normal - v;
						
						float specular = -dot(refl, r.direction);
						if (specular < 0) specular = 0;
						specular *= specular;
						specular *= specular;
						specular *= specular;
						specular *= specular;
						specular *= 2.5f;

						color += l.sample(poi) * (specular + vec3.one * cosFalloff);
					}
				}
			}
			
			if (recDepth < maxRecursion) {
				vec3 direct = color * primCol;

				vec3 reflDir = Plane(hit.normal, 0.f).reflect(r.direction).normalized;
				Ray reflRay = Ray.fromOrigDir(poi + reflDir * 0.001f, reflDir);
				vec3 bounce = colorInScene(reflRay, recDepth+1);
				return primCol * (color * .7f + bounce * .3f);
			} else {
				return color * primCol;
			}
		} else {
			return vec3.zero;
		}
	}
	
	void texSet(int x, int y, vec3 c) {
		ubyte clamp(float f) {
			if (f >= 1.f) return 255;
			if (f <= 0.f) return 0;
			return cast(ubyte)(f * 255);
		}
		uint off = (y * textureSize.x + x) * 3;
		texData[off] = clamp(c.x);
		++off;
		texData[off] = clamp(c.y);
		++off;
		texData[off] = clamp(c.z);
	}
	
	void trayRace() {
		for (int y_ = 0; y_ < textureSize.y; ++y_) {
			for (int x_ = 0; x_ < textureSize.x; ++x_) {
				float x = (cast(float)x_ / (textureSize.x) - 0.5f) * 2.f * cast(float)windowSize.x / windowSize.y;
				float y = (cast(float)y_ / (textureSize.y) - 0.5f) * 2.f;
				
				Ray r = Ray.fromOrigDir(cameraPos, vec3(x, y, -1).normalized * cameraRot);
				texSet(x_, y_, colorInScene(r));
			}
		}
	}
	
	void init(GL gl) {
		Trace.formatln("oh hai");
		
		auto h = _getGL(gl);
		assert (h !is null);

		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		gl.gluOrtho2D(-1, 1, -1, 1);
		gl.MatrixMode(GL_MODELVIEW);
		gl.LoadIdentity();

		gl.GenTextures(1, &texId);
		gl.BindTexture(GL_TEXTURE_2D, texId);
		gl.TexImage2D(GL_TEXTURE_2D, 0, 3, textureSize.x, textureSize.y, 0, GL_RGB, GL_UNSIGNED_BYTE, texData.ptr);
		gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	}	
	
	void draw(GL gl) {
		static int i, j, k, l;
		
		planes[0].d = 4 + sin(0.4f * i++);
		spheres[0].origin = vec3(-4.0, 1.5, -8.0) + vec3.unitX * quat.yRotation(j += 20);
		spheres[1].origin = vec3(2.5, 1.5, -5.0) + vec3.unitZ * quat.xRotation(l += 13);
		spheres[2].origin = vec3(0.7, -1.5, -4.2) + vec3.unitY * quat.zRotation(k += 17);

		trayRace();

		gl.BindTexture(GL_TEXTURE_2D, texId);
		gl.TexImage2D(GL_TEXTURE_2D, 0, 3, textureSize.x, textureSize.y, 0, GL_RGB, GL_UNSIGNED_BYTE, texData.ptr);

		gl.Clear(GL_COLOR_BUFFER_BIT);
		gl.Enable(GL_TEXTURE_2D);
		gl.BindTexture(GL_TEXTURE_2D, texId);
		gl.Begin(GL_QUADS);
			gl.TexCoord2f(0, 1);
			gl.Vertex2f(-1, 1);
			gl.TexCoord2f(0, 0);
			gl.Vertex2f(-1, -1);
			gl.TexCoord2f(1, 0);
			gl.Vertex2f(1, -1);
			gl.TexCoord2f(1, 1);
			gl.Vertex2f(1, 1);
		gl.End();
		gl.Disable(GL_TEXTURE_2D);
	}
	
	void cleanup(GL gl) {
		gl.DeleteTextures(1, &texId);
		texId = 0;

		delete texData;
		delete spheres;
		delete planes;
		delete lights;
		delete sphereColors;
		delete planeColors;
	}
	
	
	~this() {
		Stdout.formatln("* " ~ this.classinfo.name ~ ` dtor called`);
	}
}
