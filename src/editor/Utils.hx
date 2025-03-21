import api.IdeckiaApi.PropEditorFieldType;
import hx.Selectors.IdSel;
import api.internal.CoreApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import js.html.Element;
import js.html.Event;
import js.html.InputElement;
import js.html.OptionElement;
import js.html.SelectElement;
import haxe.ds.Option;

using StringTools;

typedef Listener = {
	var element:Element;
	var type:String;
	var callback:Event->Void;
}

class Utils {
	static var lastItemId:UInt = 0;
	static var lastStateId:UInt = 0;

	public static inline function clearElement(e:Element) {
		while (e.hasChildNodes())
			e.removeChild(e.firstChild);
	}

	public static inline function selectElement(e:Element) {
		for (s in Cls.selected.get())
			s.classList.remove(Cls.selected);

		e.classList.add(Cls.selected);
	}

	public static function hideAllProps() {
		ItemEditor.hide();
		StateEditor.hide();
		ActionEditor.hide();
	}

	public static function addListener(listeners:Array<Listener>, e:Element, t:String, cb:Dynamic->Void, once:Bool = false) {
		e.addEventListener(t, cb, {once: once});
		listeners.push({
			element: e,
			type: t,
			callback: cb
		});
	}

	public static function removeListeners(listeners:Array<Listener>) {
		for (l in listeners)
			l.element.removeEventListener(l.type, l.callback);
		listeners = [];
	}

	public static function stopPropagation(e:Event) {
		e.preventDefault();
		e.stopPropagation();
	}

	public static function getUnusedIcons() {
		var leftoverIcons = App.editorData.layout.icons.map(i -> i.key);

		var allItems = [];
		for (i in App.getAllItems())
			allItems.push(i);

		for (i in allItems) {
			switch i.kind {
				case null:
				case ChangeDir(_, state):
					if (state.icon != null && leftoverIcons.contains(state.icon))
						leftoverIcons.remove(state.icon);
				case States(_, list):
					for (state in list)
						if (state.icon != null && leftoverIcons.contains(state.icon))
							leftoverIcons.remove(state.icon);
			}
		}

		return leftoverIcons;
	}

	public static function isNumeric(typeName:String) {
		return typeName.startsWith("Int") || typeName.startsWith("UInt") || typeName.startsWith("Float");
	}

	public static function isPrimitiveTypeByName(fieldType:String) {
		return switch fieldType {
			case PropEditorFieldType.boolean | PropEditorFieldType.listOf | PropEditorFieldType.object: false;
			case x: true;
		}
	}

	public static function cloneItemKind(item:CoreItem):Kind {
		var clone:CoreItem = haxe.Json.parse(haxe.Json.stringify(item));

		switch clone.kind {
			case ChangeDir(_, state):
				state.id = getNextStateId();
				for (a in state.actions)
					a.id = null;
			case States(_, list):
				for (s in list) {
					s.id = getNextStateId();
					for (a in s.actions)
						a.id = null;
				}
		}

		return clone.kind;
	}

	public static function cloneElement<T:js.html.Element>(element:Element, cls:Class<T>):T {
		var c = Std.downcast(element.cloneNode(true), cls);
		c.removeAttribute('id');
		return c;
	}

	public static function getIconIndexByName(iconName:String) {
		for (i in 0...App.icons.length)
			if (App.icons[i].name == iconName)
				return Some(i);
		return None;
	}

	public static function createNewState():CoreState {
		return {
			id: getNextStateId(),
			text: ''
		};
	}

	public static function defaultBase64Prefix(base64:String) {
		return (base64.indexOf('base64,') == -1) ? 'data:image/jpeg;base64,' + base64 : base64;
	}

	public static function formatString(text:String, values:Array<String>) {
		for (index => value in values) {
			if (!text.contains('{$index}')) {
				js.Browser.alert('Can not found the [{$index}] placeholder in the text to overwrite with value. Text: [$text]');
				continue;
			}
			text = text.replace('{$index}', value);
		}

		return text;
	}

	public static function createNewItem():js.lib.Promise<CoreItem> {
		Id.item_kind_changedir_radio.as(InputElement).checked = false;
		Id.item_kind_states_radio.as(InputElement).checked = false;
		return new js.lib.Promise((resolveNewItem, _) -> Dialog.show('::show_title_new_item_kind::', Id.new_item_kind.get(), () -> {
			return new js.lib.Promise((resolveDialog, _) -> {
				var isChangedir = Id.item_kind_changedir_radio.as(InputElement).checked;
				var state = createNewState();

				var item:CoreItem = {
					id: Utils.getNextItemId(),
					kind: if (isChangedir) {
						ChangeDir(App.editorData.layout.dirs[0].name, state);
					} else {
						States(0, [state]);
					}
				}

				resolveNewItem(item);

				resolveDialog(true);
			});
		}));
	}

	public static function getNextItemId() {
		if (lastItemId == 0) {
			for (i in App.getAllItems()) {
				if (i.id.toUInt() > lastItemId)
					lastItemId = i.id.toUInt();
			}

			lastItemId++;
		}

		return new ItemId(lastItemId++);
	}

	public static function getNextStateId() {
		if (lastStateId == 0) {
			for (i in App.getAllItems()) {
				switch i.kind {
					case null:
					case ChangeDir(_, state):
						if (state.id.toUInt() > lastStateId)
							lastStateId = state.id.toUInt();
					case States(_, list):
						for (s in list)
							if (s.id.toUInt() > lastStateId)
								lastStateId = s.id.toUInt();
				}
			}
			lastStateId++;
		}

		return new StateId(lastStateId++);
	}

	public static function fillSelectElement(select:SelectElement, optionsArray:Array<{value:Int, text:String}>, ?onChange:Event->Void) {
		clearElement(select);

		var option:OptionElement;
		for (opt in optionsArray) {
			option = js.Browser.document.createOptionElement();
			option.value = Std.string(opt.value);
			option.text = opt.text;
			select.add(option);
		}

		if (onChange != null) {
			select.addEventListener('change', onChange);
		}
	}
}
