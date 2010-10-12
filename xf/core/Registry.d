module xf.core.Registry;



/**
	mixin(Implements("ISomeInterface"));
*/
char[] Implements(char[] T) {
	return `private static import xf.core.Registry;
	
	static this() {
		xf.core.Registry.registerConcreteClass!(`~T~`).register(
			typeof(this).stringof,
			function `~T~`(xf.core.Registry.classCtorParams!(`~T~`) args) {
				return new typeof(this)(args);
			}
		);
	}`;
}


/**
	mixin(CtorParams = "int, float, char[]");
*/
char[] CtorParams(char[] params) {
	return "private static import tango.core.Tuple; alias tango.core.Tuple.Tuple!("~params~") _ctorParams;";
}


/**
	create!(IStuff).named("Stuff")(1, 3.14f, "foobar");
	create!(ISpam)();
*/
struct create(T) {
	private struct Named {
		char[] name;
		
		T opCall(classCtorParams!(T) args) {
			alias factoryIndex!(T) idx;
			if (size_t.max == idx) {
				throw new ClassRegistryException("No implementations registered for '" ~ T.stringof ~ "'");
			}
			
			if (auto f = name in factories[idx]._named) {
				return (cast(T function(classCtorParams!(T)))*f)(args);
			} else {
				throw new ClassRegistryException("'"~name~"' is not a registered implementation of '" ~ T.stringof ~ "'");
			}
		}
	}
	
	static Named named(char[] name) {
		Named res = void;
		res.name = name;
		return res;
	}

	static T opCall(classCtorParams!(T) args) {
		alias factoryIndex!(T) idx;
		if (size_t.max == idx) {
			throw new ClassRegistryException("No implementations registered for '" ~ T.stringof ~ "'");
		}
		
		auto factory = (cast(T function(classCtorParams!(T)))factories[idx]._default);
		
		if (factory is null) {
			throw new ClassRegistryException("No default implementation registered for '" ~ T.stringof ~ "'");
		}
		
		return factory(args);
	}
}



class ClassRegistryException : Exception {
	this (char[] msg) {
		super (msg);
	}
}



// ----


private template Tuple(T ...) {
	alias T Tuple;
}


template registerConcreteClass(Abstract) {
	debug (ClassRegistry) private import tango.stdc.stdio : printf;
	
	void register(char[] name, Abstract function(classCtorParams!(Abstract)) factory) {
		assert (factory !is null);
		
		{
			int lastDot = name.length-1;
			while (lastDot >= 0 && name[lastDot] != '.') {
				--lastDot;
			}
			name = name[lastDot+1..$];
		}
		
		auto idx = &factoryIndex!(Abstract);
		if (size_t.max == *idx) {
			*idx = factories.length;
			factories ~= Factory(factory, [name : factory]);
			debug (ClassRegistry) printf("registered a class '%.*s' for abstract '%.*s': idx == %d\n", name, Abstract.stringof, *idx);
		} else {
			auto registered = &factories[*idx];
			registered._default = null;
			registered._named[name] = factory;
		}
	}
}


private {
	template classCtorParams(T) {
		static if (is(T._ctorParams)) {
			alias T._ctorParams classCtorParams;
		} else {
			alias Tuple!() classCtorParams;
		}
	}


	template factoryIndex(T) {
		size_t factoryIndex = size_t.max;
	}
	
	
	struct Factory {
		void*				_default;
		void*[char[]]		_named;
	}
	Factory[] factories;
}
