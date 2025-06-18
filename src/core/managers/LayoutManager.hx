package managers;

import exceptions.ItemNotFoundException;
import haxe.ds.Option;
import tink.Json.parse as tinkJsonParse;
import tink.Json.stringify as tinkJsonStringify;

using api.IdeckiaApi;
using api.internal.CoreApi;
using StringTools;

class LayoutManager {
	@:v('ideckia.layout-file-path:layout.json')
	static var layoutFilePath:String;
	@:v('ideckia.actions-load-timeout-ms:1000')
	static var actionsLoadTimeoutMs:UInt;

	public static var layout:Layout;
	public static var previousDir:Dir;
	public static var currentDir:Dir;
	static var currentDirName:DirName = new DirName(MAIN_DIR_ID);
	static var isWatching:Bool = false;

	static inline var DEFAULT_TEXT_SIZE = 15;
	static inline var MAIN_DIR_ID = "_main_";
	public static inline var DYNAMIC_DIRECTORY_PREFIX = "dynamicDirectory_";

	public static function getLayoutPath() {
		if (js.node.Path.isAbsolute(layoutFilePath))
			return layoutFilePath;
		return Ideckia.getAppPath(layoutFilePath);
	}

	public static function readLayout() {
		var layoutFullPath = getLayoutPath();

		Log.info('Loading layout from [$layoutFullPath]');
		try {
			layout = tinkJsonParse(sys.io.File.getContent(layoutFullPath));
		} catch (e:haxe.Exception) {
			if (e.stack != null)
				Log.raw(e.stack);
			else
				Log.raw(e);
			layout = {
				rows: 1,
				columns: 2,
				dirs: [
					{
						name: new DirName(MAIN_DIR_ID),
						items: [{}, {}]
					}
				],
				fixedItems: [],
				sharedVars: [],
				icons: []
			};
		}

		if (layout.textSize == null)
			layout.textSize = DEFAULT_TEXT_SIZE;
	}

	public static function load():js.lib.Promise<Bool> {
		readLayout();
		addIds();
		changeDir(currentDirName);
		return ActionManager.initClientActions();
	}

	public static function watchForChanges() {
		if (isWatching)
			return;

		Chokidar.watch(getLayoutPath()).on('change', (_, _) -> {
			Log.info('Layout file changed, reloading...');
			ActionManager.unloadActions();
			load().finally(() -> MsgManager.sendToAll(LayoutManager.currentDirForClient()));
		});

		isWatching = true;
	}

	public static function getCurrentItems() {
		return [for (i in currentDir.items) i];
	}

	static function hideState(state:CoreState) {
		switch ActionManager.getActionsByStateId(state.id) {
			case Some(actions):
				for (action in actions) {
					if (Utils.hasJsFunction(action, 'hide'))
						action.hide();
				}
			case None:
				Log.error('No action found to hide for state [${state.id}]');
		}
	}

	static function showState(state:CoreState):js.lib.Promise<Bool> {
		return new js.lib.Promise((resolve, reject) -> {
			var promises = [];
			switch ActionManager.getActionsByStateId(state.id) {
				case Some(actions):
					for (action in actions) {
						if (Utils.hasJsFunction(action, 'show'))
							promises.push(action.show(state));
					}
				case None:
					Log.error('No action found to show for state [${state.id}]');
			}

			var allSettled = false;
			var promisesTimeoutResolved = false;
			js.lib.Promise.allSettled(promises).then(showPromiseResponses -> {
				if (promisesTimeoutResolved)
					return;

				allSettled = true;
				for (i => response in showPromiseResponses) {
					switch response.status {
						case Fulfilled:
							var newState = response.value;
							if (newState != null) {
								state.text = newState.text;
								state.textColor = newState.textColor;
								state.textSize = newState.textSize;
								state.icon = newState.icon;
								state.bgColor = newState.bgColor;
							}
						case Rejected:
							Log.error('Error showing action of the state [id=${state.id}]: [${response.reason}]');
					}
				}

				resolve(true);
			});

			haxe.Timer.delay(() -> {
				promisesTimeoutResolved = true;
				if (!allSettled) {
					var msg = 'Not all show promises settled for state [${state.id}]';
					Log.error(msg);
					reject(msg);
				}
			}, actionsLoadTimeoutMs);
		});
	}

	public static function hideCurrentItems() {
		if (currentDir == null)
			return;
		for (item in currentDir.items) {
			switch item.kind {
				case null:
				case ChangeDir(_, state):
					hideState(state);
				case States(_, list):
					for (state in list)
						hideState(state);
			}
		}
	}

	public static function showCurrentItems() {
		return new js.lib.Promise((resolve, reject) -> {
			if (currentDir == null) {
				resolve(true);
				return;
			}
			var showPromises = [];
			for (item in currentDir.items) {
				switch item.kind {
					case null:
					case ChangeDir(_, state):
						showPromises.push(showState(state));
					case States(_, list):
						for (state in list)
							showPromises.push(showState(state));
				}
			}

			var allSettled = false;
			var promisesTimeoutResolved = false;
			js.lib.Promise.allSettled(showPromises).then(_ -> {
				if (promisesTimeoutResolved)
					return;

				allSettled = true;
				resolve(true);
			});

			haxe.Timer.delay(() -> {
				promisesTimeoutResolved = true;
				if (!allSettled) {
					var msg = 'Not all show promises settled';
					Log.error(msg);
					reject(msg);
				}
			}, actionsLoadTimeoutMs);
		});
	}

	public static function getAllItems(?fromLayout:Layout, ?getDynamicDirs:Bool = true) {
		if (fromLayout == null)
			fromLayout = layout;

		var allItems = [];
		for (f in fromLayout.dirs) {
			if (!getDynamicDirs && f.name.toString().startsWith(DYNAMIC_DIRECTORY_PREFIX))
				continue;
			for (i in f.items)
				allItems.push(i);
		}
		if (fromLayout.fixedItems != null)
			return allItems.concat(fromLayout.fixedItems);

		return allItems;
	}

	public static function getItem(itemId:ItemId) {
		for (f in layout.dirs)
			for (i in f.items)
				if (i.id == itemId)
					return i;
		if (layout.fixedItems != null)
			for (fi in layout.fixedItems)
				if (fi.id == itemId)
					return fi;

		throw new ItemNotFoundException('Could not find [$itemId] item');
	}

	public static function getItemNextState(itemId:ItemId, advanceMultiState:Bool = false):{state:CoreState, hasMultiStateChanged:Bool} {
		var item = getItem(itemId);

		var ret:{state:CoreState, hasMultiStateChanged:Bool} = switch item.kind {
			case null:
				{state: {}, hasMultiStateChanged: false};
			case ChangeDir(_, state):
				{state: state, hasMultiStateChanged: false};
			case States(index, list):
				var hasMultiStateChanged = false;
				var newIndex = index;
				if (advanceMultiState) {
					newIndex = (index + 1) % list.length;
					hasMultiStateChanged = newIndex != index;
					if (hasMultiStateChanged) {
						hideState(list[index]);
						showState(list[newIndex]);
					}
					item.kind = States(newIndex, list);
				}
				{state: list[newIndex], hasMultiStateChanged: hasMultiStateChanged};
		}

		Log.debug('State [id=${ret.state.id}] of the item [id=$itemId]: [text=${ret.state.text}],  [icon=${(ret.state.icon == null) ? null : ret.state.icon.substring(0, 50) + "..."}]');
		return ret;
	}

	public static function getSharedValue(sharedName:String) {
		if (layout.sharedVars != null) {
			for (sv in layout.sharedVars) {
				if (sv.key == sharedName)
					return Some(sv.value);
			}
		}

		return None;
	}

	public static inline function currentDirForClient():CoreMsg<ClientLayout> {
		Log.debug('Sending current directory to client.');

		var icons = new haxe.DynamicAccess<String>();
		function getIconData(iconName:String) {
			if (iconName != null && iconName.length > 100) {
				var iconMd5 = haxe.crypto.Md5.encode(iconName);
				if (!icons.exists(iconMd5))
					icons.set(iconMd5, iconName);
				return iconMd5;
			}
			if (layout.icons != null) {
				var f = layout.icons.filter(i -> i.key == iconName);
				if (f.length > 0) {
					if (!icons.exists(iconName))
						icons.set(iconName, f[0].value);
					return iconName;
				}
			}
			return null;
		}

		var rows = currentDir.rows == null ? layout.rows : currentDir.rows;
		var columns = currentDir.columns == null ? layout.columns : currentDir.columns;

		function transformItem(item:CoreItem) {
			var currentState = getItemNextState(item.id).state;

			// from CoreState to ClientItem
			var clientItem:ClientItem = {id: item.id.toUInt()};

			if (currentState != null) {
				clientItem.text = currentState.text;
				clientItem.textSize = currentState.textSize == null ? layout.textSize : currentState.textSize;
				clientItem.textColor = currentState.textColor;
				clientItem.textPosition = currentState.textPosition;
				clientItem.icon = getIconData(currentState.icon);
				clientItem.bgColor = currentState.bgColor;
			}

			return clientItem;
		}

		return {
			type: CoreMsgType.layout,
			data: {
				rows: rows,
				columns: columns,
				bgColor: currentDir.bgColor,
				icons: icons,
				items: getCurrentItems().map(transformItem),
				fixedItems: layout.fixedItems == null ? [] : layout.fixedItems.map(transformItem)
			}
		};
	}

	public static function generateDynamicDirectory(parentItemId:ItemId, dynamicDir:DynamicDir):js.lib.Promise<Bool> {
		return new js.lib.Promise((resolve, reject) -> {
			Log.debug('Generating dynamic directory from item [$parentItemId].');

			var newDirName = new DirName('${DYNAMIC_DIRECTORY_PREFIX}${parentItemId}');
			for (index => d in layout.dirs)
				if (d.name == newDirName)
					layout.dirs.splice(index, 1);

			var coreItems = [];
			var initPromises = [];
			var sItem, sState, actions;
			for (i in dynamicDir.items) {
				actions = i.actions == null ? [] : i.actions.map(a -> {
					id: ActionId.next(),
					enabled: true,
					name: a.name,
					props: a.props,
					status: a.status
				});
				sState = {
					id: StateId.next(),
					actions: actions,
					text: i.text,
					textSize: i.textSize,
					textColor: i.textColor,
					textPosition: i.textPosition,
					icon: i.icon,
					bgColor: i.bgColor
				}
				if (i.toDir != null && i.toDir != '') {
					sItem = {
						id: ItemId.next(),
						kind: Kind.ChangeDir(new DirName(i.toDir), sState)
					};
				} else {
					sItem = {id: ItemId.next(), kind: Kind.States(0, [sState])};
					initPromises.push(ActionManager.loadAndInitAction(sItem.id, sState));
				}
				coreItems.push(sItem);
			};
			layout.dirs.push({
				name: newDirName,
				rows: dynamicDir.rows,
				bgColor: dynamicDir.bgColor,
				columns: dynamicDir.columns,
				items: coreItems
			});

			initPromises.push(changeDir(newDirName));

			js.lib.Promise.allSettled(initPromises).then(initPromisesResponse -> resolve(true));
		});
	}

	public static function checkChangeDir(itemId:ItemId) {
		var item = getItem(itemId);

		return switch item.kind {
			case ChangeDir(toDir, _):
				Some(toDir);
			default:
				None;
		}
	}

	public static function isItemVisible(itemId:ItemId) {
		return getCurrentItems().filter(item -> item.id == itemId).length > 0;
	}

	public static function gotoMainDir():js.lib.Promise<Bool> {
		return changeDir(new DirName(MAIN_DIR_ID));
	}

	public static function gotoPreviousDir():js.lib.Promise<Bool> {
		return if (previousDir != null) {
			changeDir(previousDir.name);
		} else {
			gotoMainDir();
		}
	}

	public static function changeDir(dirName:DirName):js.lib.Promise<Bool> {
		if (layout == null) {
			throw new haxe.Exception('There is no loaded layout. Call LayoutManager.load() first.');
		}

		return new js.lib.Promise((resolve, reject) -> {
			function _changeDir(newDir:Dir) {
				LayoutManager.hideCurrentItems();
				previousDir = currentDir;
				currentDir = newDir;
				currentDirName = currentDir.name;
				LayoutManager.showCurrentItems().finally(() -> resolve(true));
			}

			Log.info('Switching dir to [$dirName]');
			var foundDirs = layout.dirs.filter(f -> f.name == dirName);
			var foundLength = foundDirs.length;
			if (foundLength == 0) {
				var firstDir = layout.dirs[0];
				var firstDirName = firstDir.name;
				Log.error('Could not find dir with name [$dirName]. Loading [$firstDirName] directory.');
				Ideckia.dialog.error('Error switching directory', 'Could not find dir with name [$dirName]. Loading [$firstDirName] directory.');
				_changeDir(firstDir);
				return;
			} else if (foundLength > 1) {
				Log.error('Found $foundLength dirs with name [$dirName]');
			}

			_changeDir(foundDirs[0]);
		});
	}

	static function addIds() {
		// item IDs
		setItemAndStateIds(getAllItems());
		// action IDs
		setActionIds(getAllItems());
	}

	public static function appendLayout(newLayout:Layout) {
		for (newDir in newLayout.dirs) {
			var setFolderRowColums = (newDir.rows == null || newDir == null)
				&& (newLayout.rows != layout.rows || newLayout.columns != layout.columns);

			if (setFolderRowColums) {
				newDir.rows = newLayout.rows;
				newDir.columns = newLayout.columns;
			}

			layout.dirs.push(newDir);
		}

		for (ic in newLayout.icons) {
			if (layout.icons.filter(li -> li.key == ic.key).length == 0)
				layout.icons.push(ic);
		}
	}

	public static function exportLayout(?fromLayout:Layout) {
		var expLayout = (fromLayout != null) ? Reflect.copy(fromLayout) : Reflect.copy(layout);

		var expItems = getAllItems(expLayout, false);

		setItemAndStateIds(expItems, true);
		setActionIds(expItems, true);
		removeDefaults(expItems);

		return tinkJsonStringify(expLayout);
	}

	public static function exportDirs(dirNames:Array<String>):Option<{processedDirNames:Array<String>, layout:String}> {
		var expLayout = Reflect.copy(layout);
		var foundDirs = expLayout.dirs.filter(d -> dirNames.indexOf(d.name.toString()) != -1);
		if (foundDirs.length == 0)
			return None;

		var dirIconNames = [];
		var expItems = [];
		for (dir in foundDirs) {
			for (i in dir.items) {
				expItems.push(i);
				switch i.kind {
					case ChangeDir(_, state) if (state.icon != null && !dirIconNames.contains(state.icon)):
						dirIconNames.push(state.icon);
					case States(_, list):
						dirIconNames = dirIconNames.concat(list.map(s -> s.icon).filter(i -> i != null && !dirIconNames.contains(i)));
					case _:
				}
			}
		}

		setItemAndStateIds(expItems, true);
		setActionIds(expItems, true);
		removeDefaults(expItems);

		return Some({
			processedDirNames: foundDirs.map(f -> f.name.toString()),
			layout: tinkJsonStringify({
				rows: layout.rows,
				columns: layout.columns,
				dirs: foundDirs,
				icons: layout.icons.filter(ic -> dirIconNames.indexOf(ic.key) != -1)
			})
		});
	}

	static function setItemAndStateIds(items:Array<CoreItem>, toNull:Bool = false) {
		for (i in items) {
			i.id = toNull ? null : ItemId.next();
			i.kind = switch i.kind {
				case States(_, list):
					for (state in list)
						state.id = toNull ? null : StateId.next();
					States(null, list);
				case ChangeDir(toDir, state):
					state.id = toNull ? null : StateId.next();
					ChangeDir(toDir, state);
				case k:
					k;
			}
		}
	}

	static function setActionIds(items:Array<CoreItem>, toNull:Bool = false) {
		var id = 0;
		for (i in items)
			i.kind = switch i.kind {
				case States(_, list):
					for (s in list) {
						if (s.actions != null)
							for (a in s.actions)
								if (a != null)
									a.id = toNull ? null : new ActionId(id++);
					}
					States(0, list);
				case k:
					k;
			}
	}

	static function removeDefaults(items:Array<CoreItem>) {
		var defaultTextSize = layout.textSize;
		for (i in items)
			i.kind = switch i.kind {
				case States(_, list):
					for (s in list) {
						if (s.icon != null && s.icon.length > 1000)
							s.icon = null;
						if (s.textSize == defaultTextSize)
							s.textSize = null;
					}
					States(0, list);
				case k:
					k;
			}
	}
}
