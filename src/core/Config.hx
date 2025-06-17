package;

import appropos.Appropos;

@:access(appropos.Appropos)
class Config {
	static public var configDialogPath:String;
	static inline var FIELD_HEIGHT = 34;

	static public function createConfigDialogData() {
		var fields = [];
		var height = FIELD_HEIGHT;
		var f:Dynamic;

		for (key => value in Appropos.properties) {
			f = (value == 'true' || value == 'false') ? {
				check: {
					id: '${key}',
					label: key,
					label_pos: "before",
					checked: value == 'true'
				}
			} : {
				text: {
					id: key,
					label: key,
					label_pos: "next",
					text: value
				}
				};
			fields.push(f);
			height += FIELD_HEIGHT;
		}

		var json = {
			title: CoreLoc.localizeAll('::configuration_title::'),
			window_size: [400, height],
			body: fields
		}

		configDialogPath = haxe.io.Path.join([Tray.trayDir, 'config.json']);

		sys.io.File.saveContent(configDialogPath, haxe.Json.stringify(json));
	}
}
