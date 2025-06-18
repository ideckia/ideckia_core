package managers;

import api.internal.CoreApi;
import websocket.WebSocketConnection;

using api.IdeckiaApi;
using StringTools;

class EditorManager {
	public static function handleMsg(connection:WebSocketConnection, msg:EditorMsg) {
		switch msg.type {
			case getEditorData:
				sendEditorData(connection);
			case saveLayout:
				var layoutContent = LayoutManager.exportLayout(msg.layout);
				sys.io.File.saveContent(LayoutManager.getLayoutPath(), layoutContent);
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the editor.');
		}
	}

	static function sendEditorData(connection:WebSocketConnection) {
		var layoutWithoutDynamicDir = {
			rows: LayoutManager.layout.rows,
			columns: LayoutManager.layout.columns,
			sharedVars: LayoutManager.layout.sharedVars,
			textSize: LayoutManager.layout.textSize,
			dirs: LayoutManager.layout.dirs.filter(d -> !d.name.toString().startsWith(LayoutManager.DYNAMIC_DIRECTORY_PREFIX)),
			fixedItems: LayoutManager.layout.fixedItems,
			icons: LayoutManager.layout.icons
		}

		ActionManager.getEditorActionDescriptors().then(actionDescriptors -> {
			var editorData:CoreMsg<EditorData> = {
				type: CoreMsgType.editorData,
				data: {
					layout: layoutWithoutDynamicDir,
					actionDescriptors: actionDescriptors
				}
			};
			MsgManager.send(connection, editorData);
		});
	}
}
