module xf.core.InputHub;


private {
	import xf.utils.Singleton;
	import xf.core.JobHub;
	import xf.input.Input;
}



class InputHub {
	this() {
		timeChannel = new InputChannel;
		mainChannel = new InputChannel;
		//jobHub.addRepeatableJob(&update, 100);
	}
	
	
	void dispatchAll() {
		timeChannel.dispatchAll();
		mainChannel.dispatchAll();
	}
	
	
	/+void update() {
		channel.dispatchAll();
		channel.update();
	}+/
	
	
	InputChannel timeChannel;
	InputChannel mainChannel;
}


alias Singleton!(InputHub) inputHub;
