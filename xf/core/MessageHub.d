module xf.core.MessageHub;

private {
	import xf.utils.Singleton;
	import xf.core.Message;
	import xf.core.MessageHandler;
}



class MessageHub {
	void registerMessageHandler(MessageHandler mh) {
		messageHandlers ~= mh;
	}
	
	
	void sendMessage(Message msg) {
		foreach (MessageHandler mh; messageHandlers) {
			mh.handle(msg);
		}
	}
	
	
	protected {
		MessageHandler[]	messageHandlers;
	}
}


alias Singleton!(MessageHub) messageHub;
