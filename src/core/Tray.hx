import appropos.Appropos;
import websocket.WebSocketServer;

using StringTools;

class Tray {
	inline static var TRAY_DIR_NAME = 'tray';

	static var exePath = '';
	static var iconPath = '';
	static var menuPath = '';
	static var aboutDialogPath = '';

	@:v('ideckia.port:8888')
	static public var port:Int;

	@:v('ideckia.show-about-on-startup:true')
	static public var showAboutOnStartup:Bool;

	static var address:String;

	static var trayProcess:js.node.child_process.ChildProcess;
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
		var menuDef:MenuDef = haxe.Json.parse(CoreLoc.localizeAll(menuDefContent));

		menuDefContent = haxe.Json.stringify(menuDef).replace('"', '\\"');

		trayProcess = js.node.ChildProcess.spawn(exePath, ['"$menuDefContent"'], {shell: true, detached: true});
		trayProcess.unref();

		trayProcess.stdout.on('data', onTrayData);
		trayProcess.stderr.on('data', onTrayError);
		trayProcess.on('error', onTrayError);

		if (showAboutOnStartup)
			haxe.Timer.delay(showAboutDialog, 1000);
	}

	static function onTrayData(d) {
		var out = Std.string(d);
		var isEditor = out.startsWith('editor');
		var isClient = out.startsWith('client');
		if (isEditor || isClient) {
			var launchCmd = switch Sys.systemName() {
				case "Linux": 'xdg-open';
				case "Mac": 'open';
				case "Windows": 'start';
				case _: '';
			};

			var endpoint = (isEditor) ? 'editor' : 'client';
			var url = 'http://localhost:${port}/$endpoint';
			Log.debug('Opening ${out}');
			js.node.ChildProcess.spawn('$launchCmd $url', {shell: true});
		} else if (out.startsWith('about')) {
			showAboutDialog();
		} else if (out.startsWith('config')) {
			showConfigurationDialog();
		} else if (out.startsWith('quit')) {
			quitIdeckia(false);
		}
	}

	static function onTrayError(e) {
		Log.error('Tray error');
		if (e.stack != null)
			Log.raw(e.stack);
		else
			Log.raw(e);
	}

	public static function quitIdeckia(force:Bool = true) {
		if (force && trayProcess != null) {
			final pid = trayProcess.pid;
			if (Sys.systemName() == "Windows") {
				js.node.ChildProcess.exec('taskkill /PID ${pid} /T /F', (_, _, _) -> {});
			} else {
				js.Node.process.kill(-pid, 'SIGKILL');
			}
		}
		Sys.exit(0);
	}

	public static function showConfigurationDialog() {
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

	public static function showAboutDialog() {
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
		}).catchError(e -> Log.error(e));
	}

	/**
		Since the OS can't access to the pkg virtual filesystem to access the tray executable,
		it must be in an accesible directory. I extract it to the root directory of Ideckia.
	**/
	@:noCompletion
	public static function init() {
		if (!Ideckia.isPkg())
			return;

		trayDir = Ideckia.getAppPath(TRAY_DIR_NAME);

		if (!sys.FileSystem.exists(trayDir))
			sys.FileSystem.createDirectory(trayDir);

		menuPath = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, 'menu_tpl.json']);
		copyTrayExecutable();
		copyIcon();
		Config.createConfigDialogData();

		WebSocketServer.getIPAddress().then(ip -> {
			address = '$ip:$port';
			copyAbout();
		});
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

		QrCode.toFile(qrPath, '$address/client', options, (err) -> {
			Log.error('Error creating the QR code in $qrPath: $err');
		});
		var aboutFilename = 'about.json';
		var aboutContent = sys.io.File.getContent(haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, 'about_tpl.json']));
		aboutContent = CoreLoc.localizeAll(aboutContent);
		aboutContent = aboutContent.replace('::version::', Ideckia.CURRENT_VERSION);
		aboutContent = aboutContent.replace('::client_address::', 'http://$address/client');
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
