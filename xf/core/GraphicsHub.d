module xf.core.GraphicsHub;


private {
	import xf.utils.Singleton;
	import xf.dog.GLContext;
}



/**
	Containing the current display and rendering api
*/
class GraphicsHub {
	GLContext	context;
}


alias Singleton!(GraphicsHub) graphicsHub;
