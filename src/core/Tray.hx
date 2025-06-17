import appropos.Appropos;
import websocket.WebSocketServer;

using StringTools;

class Tray {
	inline static var TRAY_DIR_NAME = 'tray';

	static var exePath = '';
	static var iconPath = '';
	static var menuPath = '';
	static var aboutDialogPath = '';

	@:v('ideckia.client-path')
	static var clientPath:String;
	static var clientFullPath:String;

	@:v('ideckia.port:8888')
	static public var port:Int;

	@:v('ideckia.show-about-on-startup:true')
	static public var showAboutOnStartup:Bool;

	static var address:String;
	static public var trayDir:String;

	public static function create() {
		init();

		if (!sys.FileSystem.exists(exePath)) {
			Log.error('Tray executable [$exePath] not found.');
			return;
		}

		if (!sys.FileSystem.exists(menuPath)) {
			Log.error('Tray menu definition [$menuPath] not found.');
			return;
		}

		var menuDefContent = sys.io.File.getContent(menuPath);
		menuDefContent = menuDefContent.replace('::icon_path::', iconPath);
		menuDefContent = menuDefContent.replace('::client_disabled::', (sys.FileSystem.exists(clientFullPath)) ? '0' : '1');
		var menuDef:MenuDef = haxe.Json.parse(CoreLoc.localizeAll(menuDefContent));

		menuDefContent = haxe.Json.stringify(menuDef).replace('"', '\\"');

		var trayProcess = js.node.ChildProcess.spawn(exePath, ['"$menuDefContent"'], {shell: true});

		trayProcess.stdout.on('data', d -> {
			var out = Std.string(d);
			var isEditor = out.startsWith('editor');
			var isClient = out.startsWith('client');
			if (isEditor || isClient) {
				var launchCmd = switch Sys.systemName() {
					case "Linux": (isClient) ? '' : 'xdg-open';
					case "Mac": 'open';
					case "Windows": 'start';
					case _: '';
				};

				var launchApp = if (isEditor) {
					'http://localhost:${port}/editor';
				} else {
					clientFullPath + ' $port';
				}
				Log.debug('Opening ${out}');
				js.node.ChildProcess.spawn('$launchCmd $launchApp', {shell: true});
			} else if (out.startsWith('about')) {
				showAboutDialog();
			} else if (out.startsWith('config')) {
				showConfigurationDialog();
			} else if (out.startsWith('quit')) {
				Sys.exit(0);
			}
		});
		trayProcess.stderr.on('data', e -> {
			Log.error('Tray error');
			if (e.stack != null)
				Log.raw(e.stack);
			else
				Log.raw(e);
		});
		trayProcess.on('error', e -> {
			Log.error('Tray error');
			if (e.stack != null)
				Log.raw(e.stack);
			else
				Log.raw(e);
		});

		if (showAboutOnStartup)
			haxe.Timer.delay(showAboutDialog, 1000);
	}

	static function showConfigurationDialog() {
		Ideckia.dialog.custom(Config.configDialogPath).then(responseOpt -> {
			switch responseOpt {
				case Some(response):
					for (r in response) {
						Log.debug('${r.id} -> ${r.value}');

						Appropos.updateProps(response.map(r -> {key: r.id, value: r.value}));
					}
				case None:
			}
		});
	}

	static function showAboutDialog() {
		Ideckia.dialog.custom(aboutDialogPath).then(responseOpt -> {
			switch responseOpt {
				case Some(response):
					for (r in response) {
						if (r.id == 'show_on_startup') {
							showAboutOnStartup = r.value == 'true';
						}
					}
					copyAbout();
				case None:
			}
		});
	}

	/**
		Since the OS can't access to the pkg virtual filesystem to access the tray executable,
		it must be in an accesible directory. I extract it to the root directory of Ideckia.
	**/
	@:noCompletion
	public static function init() {
		clientFullPath = if (clientPath == null) {
			null;
		} else if (js.node.Path.isAbsolute(clientPath)) {
			clientPath;
		} else {
			Ideckia.getAppPath(clientPath);
		}

		if (!Ideckia.isPkg())
			return;

		trayDir = Ideckia.getAppPath(TRAY_DIR_NAME);

		if (!sys.FileSystem.exists(trayDir))
			sys.FileSystem.createDirectory(trayDir);

		menuPath = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, 'menu_tpl.json']);
		address = '${WebSocketServer.getIPAddress()}:$port';

		copyTrayExecutable();
		copyIcon();
		copyAbout();

		Config.createConfigDialogData();
	}

	static function copyTrayExecutable() {
		final execFilename = switch (Sys.systemName()) {
			case 'Mac':
				'ideckia_tray_macos';
			case 'Linux':
				'ideckia_tray_linux';
			case 'Windows':
				'ideckia_tray.exe';
			default:
				'';
		}
		exePath = haxe.io.Path.join([trayDir, execFilename]);
		if (execFilename != '' && !sys.FileSystem.exists(exePath)) {
			var src = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, execFilename]);
			Log.info('Copying tray executable [$execFilename] to $exePath');
			sys.io.File.copy(src, exePath);
		}
	}

	static function copyIcon() {
		final iconFilename = switch (Sys.systemName()) {
			case 'Mac' | 'Linux':
				'icon.png';
			case 'Windows':
				'icon.ico';
			default:
				'';
		}
		iconPath = haxe.io.Path.join([trayDir, iconFilename]);
		if (iconFilename != '' && !sys.FileSystem.exists(iconPath)) {
			var src = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, iconFilename]);
			Log.info('Copying tray icon [$iconFilename] to $iconPath');
			sys.io.File.copy(src, iconPath);
		}
	}

	static function copyAbout() {
		var options = {
			width: 200,
			color: {
				dark: '#974493',
				light: '#0000'
			}
		};
		var qrPath = haxe.io.Path.join([trayDir, 'qr.png']);

		QrCode.toFile(qrPath, address, options, (err) -> {
			Log.error('Error creating the QR code in $qrPath: $err');
		});
		var aboutFilename = 'about.json';
		var aboutContent = sys.io.File.getContent(haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, 'about_tpl.json']));
		aboutContent = CoreLoc.localizeAll(aboutContent);
		aboutContent = aboutContent.replace('::version::', Ideckia.CURRENT_VERSION);
		aboutContent = aboutContent.replace('::address::', address);
		aboutContent = aboutContent.replace('::qr_path::', 'file://$qrPath');
		aboutContent = aboutContent.replace('::startup_checked::', showAboutOnStartup ? 'true' : 'false');
		aboutDialogPath = haxe.io.Path.join([trayDir, aboutFilename]);
		Log.info('Copying "about" dialog [$aboutFilename] to $aboutDialogPath');
		sys.io.File.saveContent(aboutDialogPath, aboutContent);
	}
}

typedef MenuDef = {
	var icon:String;
	var menu:Array<MenuDefItem>;
}

typedef MenuDefItem = {
	var text:String;
	var disabled:UInt;
	var checked:UInt;
	var checkbox:UInt;
	var exit:UInt;
	var ?menu:Array<MenuDefItem>;
}
