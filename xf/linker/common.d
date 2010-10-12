module common;

import xf.dog.Common;
import xf.omg.core.LinearAlgebra;

abstract class Plugin {
	void init(GL gl);
	void draw(GL gl);
	void cleanup(GL gl);
}
