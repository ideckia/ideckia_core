import api.IdeckiaApi.LocalizedTexts;
import api.data.Data;

using StringTools;

class CoreLoc {
	static inline var LOCALIZATIONS_DIR = '/loc';

	static var locTexts:LocalizedTexts;

	static var isWatching = false;
	static var newLocalizationName = 'your_locale_code_here.json';

	@:v('ideckia.locale:en_UK')
	static var currentLocale:String;

	static public function init() {
		locTexts = Data.getLocalizations(haxe.io.Path.join([js.Node.__dirname, LOCALIZATIONS_DIR]));
		loadFromDisk();
	}

	static function loadFromDisk() {
		var absolutePath = Ideckia.getAppPath(LOCALIZATIONS_DIR);
		if (sys.FileSystem.exists(absolutePath)) {
			locTexts.merge(Data.getLocalizations(LOCALIZATIONS_DIR));
			watchForChanges();
		}
	}

	public static function watchForChanges() {
		if (isWatching)
			return;

		Chokidar.watch(Ideckia.getAppPath(LOCALIZATIONS_DIR)).on('change', (_, _) -> {
			Log.info('Reloading localizations...');
			init();
		});

		isWatching = true;
	}

	static public function newLocalization() {
		var absolutePath = Ideckia.getAppPath(LOCALIZATIONS_DIR);
		if (!sys.FileSystem.exists(absolutePath)) {
			sys.FileSystem.createDirectory(absolutePath);
			watchForChanges();
		}

		absolutePath += '/$newLocalizationName';
		final innerTxtPath = js.Node.__dirname + LOCALIZATIONS_DIR + '/en_UK.json';
		final innerTxtContent = sys.io.File.getContent(innerTxtPath);

		sys.io.File.saveContent(absolutePath, innerTxtContent);

		return absolutePath;
	}

	static public function localizeAll(text:String) {
		final currentLocaleLower = getCurrentLocale();
		if (!locTexts.exists(currentLocaleLower)) {
			// Try loading again, maybe the file has been created after the initialization of the app
			loadFromDisk();
			if (!locTexts.exists(currentLocaleLower)) {
				Log.error('[$currentLocaleLower] locale not found.');
				return text;
			}
		}

		var currentLocaleStrings = locTexts.get(currentLocaleLower);
		for (string in currentLocaleStrings)
			text = text.replace('::${string.id}::', string.text);

		return text;
	}

	static public function getCurrentLocale() {
		return currentLocale.toLowerCase();
	}
}
